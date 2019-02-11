# frozen_string_literal: true

# A Model is a type of a thing which is available inside
# an #InventoryPool for borrowing. If a customer wants to
# borrow a thing, he opens an #Order and chooses the
# appropriate Model. The #InventoryPool manager then hands
# him over an instance - an #Item - of that Model, in case
# one is still available for borrowing.
#
# The description of the #Item class contains an example.
#
#
class Model < ApplicationRecord
  include Availability::Model
  include DefaultPagination
  audited

  before_validation do
    # TODO: this should be done by the ActiveRecord STI
    self.type = 'Model' unless type
  end

  before_destroy do
    if is_package? and reservations.empty?
      destroyed = items.destroy_all
      throw :abort if destroyed.count != items.count
    end
  end

  # NOTE these are only the active items (unretired),
  # because Item has a default_scope
  has_many :items, dependent: :restrict_with_exception
  accepts_nested_attributes_for :items, allow_destroy: true

  # TODO: this is used by the filter
  has_many :unretired_items, -> { where(retired: nil) }, class_name: 'Item'
  # TODO:  do we need a :all_items ??
  has_many(
    :borrowable_items,
    -> { where(retired: nil, is_borrowable: true, parent_id: nil) },
    class_name: 'Item'
  )
  has_many(
    :unborrowable_items, -> { where(retired: nil, is_borrowable: false) }, class_name: 'Item'
  )
  has_many :unpackaged_items, -> { where(parent_id: nil) }, class_name: 'Item'

  # OPTIMIZE: N+1 select problem, :include => :inventory_pools
  has_many :rooms, -> { distinct }, through: :items
  has_many :inventory_pools, -> { distinct }, through: :items

  has_many :entitlements, dependent: :delete_all do
    def set_in(inventory_pool, new_entitlements)
      joins(:entitlement_group).where(entitlement_groups: { inventory_pool_id: inventory_pool })
        .scoping do
        delete_all
        new_entitlements.delete(EntitlementGroup::GENERAL_GROUP_ID)
        unless new_entitlements.blank?
          valid_entitlement_group_ids = inventory_pool.entitlement_group_ids
          new_entitlements.each_pair do |entitlement_group_id, quantity|
            entitlement_group_id = entitlement_group_id
            quantity = Integer(quantity.presence || 0)
            unless (valid_entitlement_group_ids.include?(entitlement_group_id) and quantity > 0)
              next
            end
            create(entitlement_group_id: entitlement_group_id, quantity: quantity)
          end
        end
        # if there's no more items of a model in a group accessible to
        # the customer, then he shouldn't be able to
        # see the model in the frontend.
      end
    end
  end
  accepts_nested_attributes_for :entitlements, allow_destroy: true

  has_many :reservations, dependent: :restrict_with_exception
  has_many :properties, dependent: :destroy
  accepts_nested_attributes_for :properties, allow_destroy: true

  has_many :accessories, dependent: :destroy do
    def active_in(inventory_pool)
      joins(:inventory_pools).where(inventory_pools: { id: inventory_pool })
    end
  end
  accepts_nested_attributes_for :accessories, allow_destroy: true

  has_many :images, -> { where(thumbnail: false) }, as: :target, dependent: :destroy
  accepts_nested_attributes_for :images, allow_destroy: true

  has_many :attachments, dependent: :destroy
  accepts_nested_attributes_for :attachments, allow_destroy: true

  # ModelGroups
  has_many :model_links, dependent: :destroy
  has_many :model_groups, -> { distinct }, through: :model_links
  has_many(:categories, -> { where(type: 'Category') }, through: :model_links, source: :model_group)
  has_many(:templates, -> { where(type: 'Template') }, through: :model_links, source: :model_group)

  ########
  # says which other Model one Model works with
  has_and_belongs_to_many :compatibles,
                          -> { distinct },
                          class_name: 'Model',
                          join_table: 'models_compatibles',
                          foreign_key: 'model_id',
                          association_foreign_key: 'compatible_id'

  #############################################

  validate do
    if product.blank?
      errors.add(:base, _('The model needs a product name.'))
    else
      exists = Model.where.not(id: self.id).where(product: product).where(version: version).any?

      if exists
        if version.blank?
          errors.add(
            :base,
            _(
              'A model with the same product name ' \
                'and empty version already exists.'
            )
          )
        else
          errors.add(
            :base,
            _(
              'A model with the same product name ' \
                'and version already exists.'
            )
          )
        end
      end
    end
  end

  #############################################

  scope :active, -> { joins(:items).where(items: { retired: nil }).distinct }

  scope(
    :without_items,
    (lambda do
      select('models.*').joins('LEFT JOIN items ON items.model_id = models.id').where(
        ['items.model_id IS NULL']
      )
    end)
  )

  scope(
    :unused_for_inventory_pool,
    (lambda do |ip|
      model_ids =
        Model.select('models.id').joins(:items).where(
          ':id IN (items.owner_id, items.inventory_pool_id)', id: ip.id
        )
          .distinct
      Model.where("models.id NOT IN (#{model_ids.to_sql})")
    end)
  )

  scope :packages, -> { where(is_package: true) }

  scope :with_properties,
        lambda do
          joins('LEFT JOIN properties ON properties.model_id = models.id').where.not(
            properties: { model_id: nil }
          )
            .distinct
        end

  scope :by_inventory_pool,
        lambda do |inventory_pool|
          joins(:items).where(['items.inventory_pool_id = ?', inventory_pool])
        end

  scope(
    :owned_or_responsible_by_inventory_pool,
    (lambda do |ip|
      joins(:items).where(':id IN (items.owner_id, items.inventory_pool_id)', id: ip.id).distinct
    end)
  )

  scope(
    :all_from_inventory_pools,
    (lambda { |inventory_pool_ids| where(items: { inventory_pool_id: inventory_pool_ids }) })
  )

  scope(
    :by_categories,
    (lambda do |categories|
      joins('INNER JOIN model_links AS ml').where(['ml.model_group_id IN (?)', categories]) # OPTIMIZE: no ON ??
    end)
  )

  scope(
    :from_category_and_all_its_descendants,
    (lambda do |category|
      joins(:categories).where(
        model_groups: { id: Category.find(category.id).self_and_descendants }
      )
    end)
  )

  scope(
    :order_by_attribute_and_direction,
    (lambda do |attr, direction|
      if %w[product version manufacturer].include? attr and ['asc', 'desc'].include? direction
        order "#{attr} #{direction.upcase}"
      else
        default_order
      end
    end)
  )

  scope :default_order, -> { order_by_attribute_and_direction('product', 'asc') }

  # not using scope because not working properly
  # (if result of first is nil, an additional query is performed returning all)
  def self.find_by_name(name)
    find_by("CONCAT_WS(' ', product, version) = ?", name) || find_by_product(name) ||
      find_by_version(name)
  end

  def self.manufacturers
    distinct.order(:manufacturer).pluck(:manufacturer).reject { |s| s.nil? || s.strip.empty? }
  end

  #############################################

  SEARCHABLE_FIELDS = %w[manufacturer product version]

  scope(
    :search,
    (lambda do |query, fields = []|
      return all if query.blank?

      # old# joins(:categories, :properties, :items)
      sql = distinct
      if fields.empty?
        sql =
          sql.joins(
            'LEFT JOIN model_links AS ml2 ' \
              'ON ml2.model_id = models.id'
          )
            .joins(
            'LEFT JOIN model_groups AS mg2 ON ' \
              'mg2.id = ml2.model_group_id ' \
              "AND mg2.type = 'Category'"
          )
            .joins(
            'LEFT JOIN properties AS p2 ' \
              'ON p2.model_id = models.id '
          )
      end
      if fields.empty? or fields.include?(:items)
        sql =
          sql.joins('LEFT JOIN items AS i2 ON i2.model_id = models.id').joins(
            'LEFT JOIN rooms AS r ON r.id = i2.room_id'
          )
            .joins('LEFT JOIN items AS i3 ON i3.parent_id = i2.id')
            .joins('LEFT JOIN models AS m3 ON m3.id = i3.model_id')
      end

      # FIXME: refactor to Arel
      query.split.each do |x|
        s = []
        s1 = ["' '"]
        SEARCHABLE_FIELDS.each do |field|
          s1 << "models.#{field}" if fields.empty? or fields.include?(field.to_sym)
        end
        s << "CONCAT_WS(#{s1.join(', ')}) ILIKE :query"
        if fields.empty?
          s << 'mg2.name ILIKE :query'
          s << 'p2.value ILIKE :query'
        end
        if fields.empty? or fields.include?(:items)
          model_fields = Model::SEARCHABLE_FIELDS.map { |f| "m3.#{f}" }.join(', ')
          item_fields_2 = Item::SEARCHABLE_FIELDS.map { |f| "i2.#{f}" }.join(', ')
          item_fields_3 = Item::SEARCHABLE_FIELDS.map { |f| "i3.#{f}" }.join(', ')
          room_fields = Room::SEARCHABLE_FIELDS.map { |f| "r.#{f}" }.join(', ')
          s <<
            "CONCAT_WS(' ', " \
              "#{model_fields}, " \
              "#{item_fields_2}, " \
              "#{item_fields_3}, " \
              "#{room_fields}) ILIKE :query"
        end

        sql = sql.where(format('%s', s.join(' OR ')), query: "%#{x}%")
      end
      sql
    end)
  )

  def self.filter(params, subject = nil, category = nil, borrowable = false)
    models =
      if subject.is_a? User
        filter_for_user params, subject, category, borrowable
      elsif subject.is_a? InventoryPool
        filter_for_inventory_pool params, subject, category
      else
        Model.all
      end

    if ['model', 'software'].include? params[:type]
      models = models.where(type: params[:type].capitalize)
    end
    models = models.where(is_package: params[:packages] == 'true') if params[:packages]

    models = models.where(id: params[:id]) if params[:id]
    models = models.where(id: params[:ids]) if params[:ids]

    unless params[:search_term].blank?
      models =
        models.search params[:search_term],
        (params[:search_targets] ? params[:search_targets] : [:manufacturer, :product, :version])
    end
    models = models.order_by_attribute_and_direction params[:sort], params[:order]
    models = models.default_paginate params unless params[:paginate] == 'false'
    models
  end

  def self.filter_for_user(params, user, category, borrowable = false)
    models = user.models
    models = models.from_category_and_all_its_descendants(category) if category
    models = models.borrowable if borrowable
    unless params[:inventory_pool_ids].blank?
      models =
        models.all_from_inventory_pools user.inventory_pools.where(id: params[:inventory_pool_ids])
          .map(&:id)
    end
    models
  end

  def self.filter_for_inventory_pool(params, inventory_pool, _category)
    case params[:used]
    when 'false'
      models = Model.unused_for_inventory_pool inventory_pool
    when 'true'
      models =
        if params[:as_responsible_only]
          Model.joins(:items).where(items: { inventory_pool_id: inventory_pool }).distinct
        else
          Model.joins(:items).where(
            ':id IN (items.owner_id, ' \
              'items.inventory_pool_id)',
            id: inventory_pool.id
          )
            .distinct
        end
      models = models.where(items: { parent_id: nil }) unless params[:include_package_models]
      if params[:borrowable] == 'true'
        models = models.joins(:items).where(items: { is_borrowable: true })
      end
      models = models.joins(:items).where(items: { id: params[:items] }) if params[:items]
      if params[:responsible_inventory_pool_id]
        models =
          models.joins(:items).where(
            items: { inventory_pool_id: params[:responsible_inventory_pool_id] }
          )
      end
    else
      models = Model.all
    end

    unless params[:category_id].blank?
      if params[:category_id] == '00000000-0000-0000-0000-000000000000'
        models = models.where.not(id: Model.joins(:categories))
      else
        models =
          models.joins(:categories).where(
            :"model_groups.id" =>
              [Category.find(params[:category_id])] +
                Category.find(params[:category_id]).descendants
          )
      end
    end
    if params[:template_id]
      models =
        models.joins(:model_links).where(model_links: { model_group_id: params[:template_id] })
    end
    models
  end

  #############################################

  def to_s
    "#{name}"
  end

  def label_for_audits
    "#{name}"
  end

  def name
    [product, version].compact.join(' ')
  end

  # compares two objects in order to sort them
  def <=>(other)
    self.name.downcase <=> other.name.downcase
  end

  def image(offset = 0)
    images.offset(Integer(offset.presence || 0)).first
  end

  def needs_permission
    items.each { |item| return true if item.needs_permission }
    false
  end

  #############################################

  # returns an array of reservations
  def add_to_contract(contract, user, quantity = nil, start_date = nil, end_date = nil, delegated_user_id = nil)
    contract.add_lines(quantity, self, user, start_date, end_date, delegated_user_id)
  end

  #############################################

  def total_borrowable_items_for_user_and_pool(user, inventory_pool, ensure_non_negative_general: false)
    groups = user.entitlement_groups.with_general
    entitled_quantity =
      Entitlement.hash_with_generals(
        inventory_pool, self, groups, ensure_non_negative_general: ensure_non_negative_general
      )
        .values
        .sum
    borrowable_quantity = borrowable_items.where(inventory_pool_id: inventory_pool.id).count
    [entitled_quantity, borrowable_quantity].min
  end

  def total_borrowable_items_for_user(user, ensure_non_negative_general: false)
    groups = user.entitlement_groups.with_general
    entitled_quantity =
      inventory_pools.to_a.sum do |ip|
        Entitlement.hash_with_generals(
          ip, self, groups, ensure_non_negative_general: ensure_non_negative_general
        )
          .values
          .sum
      end
    borrowable_quantity = borrowable_items.where(inventory_pool_id: user.inventory_pools).count
    [entitled_quantity, borrowable_quantity].min
  end

  def as_json_with_arguments(accessories_for_ip: nil, **options)
    h = as_json_without_arguments(options)
    if accessories_for_ip
      h['accessory_names'] = accessories.active_in(accessories_for_ip).map(&:name).join(', ')
    end
    h
  end
  alias_method :as_json_without_arguments, :as_json
  alias_method :as_json, :as_json_with_arguments
end

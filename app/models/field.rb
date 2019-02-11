# -*- encoding : utf-8 -*-

class Field < ApplicationRecord
  audited

  ####################################

  GROUPS_ORDER = [
    nil,
    'General Information',
    'Status',
    'Location',
    'Inventory',
    'Invoice Information',
    'Umzug',
    'Toni Ankunftskontrolle',
    'Maintenance'
  ]

  default_scope { where(active: true).order(:position) }

  ####################################

  def value(item)
    Array(data['attribute']).inject(item) do |r, m|
      r.is_a?(Hash) ? r[m] : m == 'id' ? r : r.try(:send, m)
    end
  end

  def set_default_value(item)
    return unless data.key?('default')
    return unless value(item).nil?

    attrs = Array(data['attribute'])
    attrs.inject(item) do |r, m|
      if m == attrs[-1]
        r.is_a?(Hash) ? r[m] = default : r.send "#{m}=", default
      else
        r.is_a?(Hash) ? r[m] : r.send m
      end
    end
  end

  def values
    case data['values']
    when 'all_inventory_pools'
      (InventoryPool.all.map { |x| { value: x.id, label: x.name } }).as_json
    when 'all_buildings'
      Building.all.map { |x| { value: x.id, label: x.to_s } }.as_json
    when 'all_suppliers'
      Supplier.order(:name).map { |x| { value: x.id, label: x.name } }.as_json
    when 'all_currencies'
      Money::Currency.all.map(&:iso_code).uniq.sort.map do |iso_code|
        { label: iso_code, value: iso_code }
      end
    else
      data['values']
    end
  end

  def default
    case data['default']
    when 'today'
      Time.zone.today.as_json
    else
      data['default']
    end
  end

  def search_path(inventory_pool)
    case data['search_path']
    when 'models'
      Rails.application.routes.url_helpers.manage_models_path(inventory_pool, all: true)
    when 'software'
      Rails.application.routes.url_helpers.manage_models_path(
        inventory_pool, all: true, type: :software
      )
    else
      data['search_path']
    end
  end

  def as_json(options = {})
    h = data.clone
    h[:id] = id
    h[:values] = values
    h[:default] = default
    h[:search_path] = search_path options[:current_inventory_pool]
    h[:hidden] = true if options[:hidden_field_ids].try :include?, id.to_s
    h.as_json options
  end

  def get_value_from_params(params)
    if data['attribute'].is_a? Array
      begin
        data['attribute'].inject(params) do |params, attr|
          params.is_a? Hash ? params[attr.to_sym] : params.send attr
        end
      rescue StandardError
        nil
      end
    else
      params[data['attribute']]
    end
  end

  def editable(user, inventory_pool, item)
    return true unless data['permissions']

    if data['permissions']['role'] and
      not user.has_role? data['permissions']['role'], inventory_pool
      return false
    end
    return false if data['permissions']['owner'] and item.owner != inventory_pool

    true
  end

  ########

  def accessible_by?(user, inventory_pool)
    data['permissions'] ? user.has_role? data['permissions']['role'], inventory_pool : true
  end

  def label_for_audits
    id
  end
end

def fill_in_via_autocomplete(css:, text: nil, value:)
  find(css, text: text).set value
  find('.ui-menu-item', match: :prefer_exact, text: value, visible: true).click
end

def get_rails_model_name_from_url
  path_array_reversed = current_path.split('/').reverse

  model_name =
    case action = path_array_reversed.first
    when 'new'
      path_array_reversed[1].chomp('s')
    when 'edit'
      id = path_array_reversed[1].chomp('s')
      path_array_reversed[2].chomp('s')
    else
      raise 'Unspecified action'
    end

  if model_name == 'model' and
    (current_url =~ /type=software/ or Model.where(id: id, type: 'Software').first)
    model_name = 'software'
  end
  model_name
end

def rescue_displaced_flash
  begin
    yield
  rescue StandardError
    find('#flash .fa-times-circle').click
    retry
  end
end

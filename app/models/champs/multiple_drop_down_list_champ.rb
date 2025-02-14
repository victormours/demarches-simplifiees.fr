# == Schema Information
#
# Table name: champs
#
#  id                             :integer          not null, primary key
#  data                           :jsonb
#  fetch_external_data_exceptions :string           is an Array
#  prefilled                      :boolean          default(FALSE)
#  private                        :boolean          default(FALSE), not null
#  rebased_at                     :datetime
#  type                           :string
#  value                          :string
#  value_json                     :jsonb
#  created_at                     :datetime
#  updated_at                     :datetime
#  dossier_id                     :integer
#  etablissement_id               :integer
#  external_id                    :string
#  parent_id                      :bigint
#  row_id                         :string
#  type_de_champ_id               :integer
#
class Champs::MultipleDropDownListChamp < Champ
  validate :values_are_in_options, if: -> { value.present? }

  def options?
    drop_down_list_options?
  end

  def options
    drop_down_list_options
  end

  def disabled_options
    drop_down_list_disabled_options
  end

  def enabled_non_empty_options
    drop_down_list_enabled_non_empty_options
  end

  THRESHOLD_NB_OPTIONS_AS_CHECKBOX = 5

  def search_terms
    selected_options
  end

  def selected_options
    value.blank? ? [] : JSON.parse(value)
  end

  def to_s
    selected_options.join(', ')
  end

  def for_tag
    selected_options.join(', ')
  end

  def for_export
    value.present? ? selected_options.join(', ') : nil
  end

  def render_as_checkboxes?
    enabled_non_empty_options.size <= THRESHOLD_NB_OPTIONS_AS_CHECKBOX
  end

  def blank?
    selected_options.blank?
  end

  def in?(options)
    (selected_options - options).size != selected_options.size
  end

  def remove_option(options)
    update_column(:value, (selected_options - options).to_json)
  end

  def focusable_input_id
    render_as_checkboxes? ? checkbox_id(options.find(&:present?)) : input_id
  end

  def checkbox_id(value)
    "#{input_id}-#{Digest::MD5.hexdigest(value)}"
  end

  def next_checkbox_id(value)
    return nil if value.blank? || !selected_options.include?(value)
    index = selected_options.index(value)
    next_values = selected_options.reject { _1 == value }
    next_value = next_values[index] || next_values.last
    next_value ? checkbox_id(next_value) : nil
  end

  def unselected_options
    enabled_non_empty_options - selected_options
  end

  def value=(value)
    return super(nil) if value.nil?

    values = if value.is_a?(Array)
      value
    elsif value.starts_with?('[')
      JSON.parse(value)
    else
      selected_options + [value]
    end.uniq.without('')

    if values.empty?
      super(nil)
    else
      super(values.to_json)
    end
  end

  private

  def values_are_in_options
    json = selected_options.compact_blank
    return if json.empty?
    return if (json - enabled_non_empty_options).empty?

    errors.add(:value, :not_in_options)
  end
end

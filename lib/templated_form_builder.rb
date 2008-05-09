class TemplatedFormBuilder < ActionView::Helpers::FormBuilder
  TEMPLATED_FORM_BUILDER_BLOCK_OPTIONS    = [ :label, :explanation, :control_suffix ]
  TEMPLATED_FORM_BUILDER_STANDARD_INPUTS  = (field_helpers - %w(fields_for check_box radio_button hidden_field  apply_form_for_options!))
  attr_accessor :template_options

  # Specify the partial to use for a particular input using the FormHelper method for that input type
  # as the key to the paritials option hash.
  # form_for @contact, :builder => TemplatedFormBuilder, :partials => { :collection_select => 'collection_select' }
  # form_for @contact, :builder => TemplatedFormBuilder, :template => 'basic'
  def initialize(object_name, object, template, options, proc)
    @object_name, @object, @template, @options, @proc = object_name, object, template, options, proc        
    self.template_options = {}

    raise ArgumentError.new("TemplatedFormBuilder requires that you specify a template name. #{options.inspect}") unless options[:template]
    template_options[:builder] = self.class
    template_options[:template] = options[:template]
    template_options[:partials] = options[:partials] || {}

    # In Kongregate basic usage, these types can all use the same partial.
    (TEMPLATED_FORM_BUILDER_STANDARD_INPUTS + [ :collection_select ] ).map(&:to_sym).each do |selector|
      template_options[:partials][selector] = 'input' unless template_options[:partials][selector]
    end

    # Each of these gets their own partial.
    [ :check_box, :radio_button ].each do |selector|
      template_options[:partials][selector] = selector.to_s unless template_options[:partials][selector]
    end
  end

  def partial_template selector
    File.join('shared/form_builder_templates', template_options[:template], template_options[:partials][selector] || selector.to_s)
  end

  def fields_for_with_templated_form_builder(name, *args, &block)
    # TemplatedFormBuilder makes itself the default form builder for fields generated beneath it.
    options = args.last.is_a?(Hash) ? args.pop : {}
    fields_for_without_templated_form_builder(name, *(args << options.reverse_merge( template_options )), &block)
  end
  alias_method_chain :fields_for, :templated_form_builder

  # Custom controls
  def collection_select_with_template(field, collection, value_method, text_method, options = {})
    @template.render(
      :partial => partial_template(:collection_select),
      :locals => templated_form_builder_locals(field, options).merge(
        :control => collection_select_without_template(field, collection, value_method, text_method, options.block(*TEMPLATED_FORM_BUILDER_BLOCK_OPTIONS))
      )
    )
  end
  alias_method_chain :collection_select, :template

  def check_box_with_template(field, options = {}, checked_value = '1', unchecked_value = '0')
    @template.render(:partial => partial_template(:check_box),
      :locals => templated_form_builder_locals(field, options).merge(
        :control => check_box_without_template(
          field,
          options.block(*TEMPLATED_FORM_BUILDER_BLOCK_OPTIONS).merge(
            :class => "check_box#{options[:class] ? ' ' : ''}#{options[:class]}"
          ),
          checked_value,
          unchecked_value
        )
      )
    )
  end
  alias_method_chain :check_box, :template

  def radio_button_with_template(field, tag_value, options = {})
    @template.render(:partial => partial_template(:radio_button),
      :locals => templated_form_builder_locals(field, options.reverse_merge(:label => tag_value)).merge(
        :control => radio_button_without_template(
          field,
          tag_value,
          options.block(*TEMPLATED_FORM_BUILDER_BLOCK_OPTIONS).merge(
            :class => "radio_button#{options[:class] ? ' ' : ''}#{options[:class]}"
          )
        ),
        :identifier => "#{flat_object_name}_#{field}_#{tag_value.downcase}",
        :radio_field => "#{field}_#{tag_value.downcase}"
      )
    )
  end
  alias_method_chain :radio_button, :template

  def date_select_with_template(field, options = {})
    @template.render(:partial => partial_template(:date_select),
      :locals => templated_form_builder_locals(field, options).merge(
        :control => date_select_without_template(
          field,
          options.block(*TEMPLATED_FORM_BUILDER_BLOCK_OPTIONS).merge(
            :class => "date_select#{options[:class] ? ' ' : ''}#{options[:class]}"
          )
        ),
        :identifier => "#{flat_object_name}_#{field}"
      )
    )
  end
  alias_method_chain :date_select, :template

  src = ''
  TEMPLATED_FORM_BUILDER_STANDARD_INPUTS.each do |selector| 
    src << <<-END_SRC
    def #{selector}_with_template(field, options = {})
      # Generate consistent templated output for form elements
      #
      # <dt id="field_errors" class="errorIndicator"> ERRORS ON FIELD </dt>
      # <dt id="field_label"><label for="field">field (or options[:label])</label></dt>
      # <dd id="field_control"> YOUR CONTROL </dd>
      # <dt id="field_explanation"><em> YOUR EXPLANATION (options[:explanation])</em></dt>
      #
      # The entire <dt> containing the explanation of errors on a field will be omitted from
      # output if there are no errors on the given field.
      #
      # The entire <dt> containing the explanation of the field will be omitted from output
      # if no explanation is explicitly supplied.
      #
      # The <em> tag surrounding the explanation is automatically applied.
      # Markup within the explanation is not escaped.

      @template.render(
        :partial => partial_template(:#{selector}),
        :locals => templated_form_builder_locals(field, options).merge(
          :control => #{selector}_without_template(field, options.block(*TEMPLATED_FORM_BUILDER_BLOCK_OPTIONS))
        )
      )
    end
    alias_method_chain :#{selector}, :template
    END_SRC
  end

  class_eval src, __FILE__, __LINE__ 

  private
  def flat_object_name
    object_name.to_s.gsub('[','_').gsub(']','')
  end

  def templated_form_builder_mandatory_locals options
    {
      :builder => self,
      :explanation => options.delete(:explanation),
      :options => options
    }
  end

  def templated_form_builder_locals field, options
    templated_form_builder_mandatory_locals(options).merge(
      :field => field,
      :identifier => "#{flat_object_name}_#{field}"
    )
  end
end

module ActionView
  module Helpers
    class InstanceTag

      def object
        @object || extract_target_object(@object_name)
      end

      def extract_target_object(object_name)
        # Get from root, works for unscoped forms
        # Initial instance variable must be set and associations are traversed
        # So if this instance tag is attempting to extract a value from an object_name
        # contact[user][username], it will first peer into @contact, and then traverse the user association,
        # and then retrieve the username attribute
        object_attrs = object_name.to_s.gsub(']','').split('[')
        result_object = @template_object.instance_variable_get("@#{object_attrs.shift}")

        if result_object
          object_attrs.each do |attr|
            result_object = result_object.send(attr)
          end
        else
          result_object = @template_object.instance_variable_get("@object")
        end

        result_object
      end
    end

  end
end

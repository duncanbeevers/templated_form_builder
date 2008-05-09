module ActionView
  module Helpers
    class InstanceTag

      def to_label_tag(options = {})
        options = options.stringify_keys
        options['id'] = "#{sanitized_object_name}_#{@method_name}"
        options['for'] = options.delete('id')
        content_tag 'label', options.delete('label') || @method_name.humanize, options
      end

    end

    module FormHelper

      # First define functionality for unsupported tags
      # Label methods lifted from technoweenie's labeled_form_helper
      def label_for(object_name, method, options = {})
        ActionView::Helpers::InstanceTag.new(object_name, method, self, nil, options.delete(:object)).to_label_tag(options)
      end

      def label_tag(name, text, options = {})
        content_tag('label', text, { :for => name }.merge(options.symbolize_keys))
      end

    end

    class FormBuilder

      def label_for(method, options = {})
        @template.label_for(@object_name, method, options.merge(:object => @object))
      end

    end

  end
end
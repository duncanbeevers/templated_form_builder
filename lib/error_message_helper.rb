# Kongregate 2007
# Duncan Beevers


module ActionView
  module Helpers
    module FormHelper

      # Generate the large error message block describing all the errors that occured in saving a model
      # Example usage:
      # <%= error_messages_for :contact %>
      #
      # Note, this is a custom form helper method and as such will not automatically have a
      # corrolary generated for use in a FormBuilder.
      # However, the TemplatedFormBuilder provides this functionality.
      def error_messages_for object_reference, options = {}
        object = object_reference.kind_of?(Symbol) || object_reference.kind_of?(String) ? instance_variable_get("@#{object_reference}") : object_reference
        options[:object_name] ||= object.class.to_s.underscore.humanize
        options[:html] ||= { :id => 'errorExplanation' }

        count = object.respond_to?(:errors) ? object.errors.count : 0
        unless count.zero?
          header_message = "#{pluralize(count, 'error')} prohibited this #{options[:object_name]} from being saved."
          error_messages = object.errors.full_messages.map { |error| content_tag(:li, error) }
          content_tag(:div, content_tag(:p, header_message) + content_tag(:ul, error_messages), options[:html])
        else
          nil
        end
      end

      # Generate individual error messages for fields with errors
      # Usage:
      #
      # error_message_on :contact, :name
      #
      def error_message_on(object_name, method, options = {})
        error_strings = InstanceTag.new(object_name, method, self, nil, options.delete(:object)).to_error_message_on(options)
        unless error_strings.blank?
          if options[:partial]
            @template.render_to_string :partial => options[:partial],
              :locals => error_message_helper_locals(error_strings, object_name, method, options.block(:partial))
          else
            content_tag(:ul, error_strings.map { |e| content_tag(:li, e) } )
          end
        end
      end

      private
      def flat_object_name object_name
        object_name.to_s.gsub('[','_').gsub(']','')
      end

      def error_message_helper_locals error_strings, object_name, field, options
        {
          :errors => error_strings,
          :options => options,
          :field => field,
          :identifier => "#{flat_object_name(object_name)}_#{field}"
        }
      end
    end

    class FormBuilder
      def error_message_on(method, options = {})
        @template.send(:error_message_on, @object_name, method, options.merge(:object => @object))
      end
    end

    class InstanceTag
      # Unorthodox use of InstanceTag to generate arrays of error message strings, not tags at all.
      def to_error_message_on(options = {})
        options = options.symbolize_keys
        if object.respond_to?(:errors)
          errors = object.errors.on(method_name)
          case errors
          when Array
            errors.map { |error| error_string(error, options) }
          when String
            [ error_string(errors, options) ]
          else
            nil
          end
        else
          nil
        end
      end

      private
      def error_string error, options = {}
        "#{options[:error_prefix]}#{method_name.humanize} #{error}"
      end
    end

  end
end

class TemplatedFormBuilder
  def error_message_on(method, options = {})
    @template.send(:error_message_on, @object_name, method, options.merge(:object => @object, :partial => partial_template(:error_message_on)))
  end
end

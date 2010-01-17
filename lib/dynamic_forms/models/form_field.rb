# The FormField is an abstract model of a field that is in a form. It holds information about
# naming, labelling, validation etc. for that field. It is subclassed for each kind of form field.
module DynamicForms
  module Models
    module FormField
      
      TYPES = %w{text_field text_area select check_box check_box_group}
      VALIDATION_TYPES = %w{required number max_length min_length}
      
      def self.included(model)
        model.extend(ClassMethods)
        
        model.send(:include, InstanceMethods)
        model.send(:include, Relationships)
        model.send(:include, Callbacks)
        model.send(:include, Validations)
        model.send(:include, DynamicForms::Extensions::DynamicValidations)
        
        model.class_eval do
          alias_method_chain :name, :default
          attr_accessor :answer, :submission
        end
      end
      
      module Relationships
        def self.included(model)
          model.class_eval do
            belongs_to :form,
                       :class_name => "::Form"
            
            has_many :form_field_options, 
                     :class_name => "::FormFieldOption",
                     :order => 'position ASC, label ASC'
          end
        end
      end
      
      module Callbacks
        def self.included(model)
          model.class_eval do
            before_validation :assign_name
          end
        end
      end
      
      module Validations
        def self.included(model)
          model.class_eval do
            validates_presence_of :name
          end
        end
      end
      
      module InstanceMethods
        def validate_submission(form_submission)
          self.submission = form_submission
          self.answer = submission.send(name)
          VALIDATION_TYPES.each do |validation|
            self.send("validate_#{validation}".to_sym)
          end
        end
        
        def kind
          self.class.to_s.split("::").last.underscore
        end
        
        # overridden by has_many_responses
        def has_many_responses?
          false
        end
        
        # overridden by acts_as_selector
        def is_selector?
          false
        end
        
        # for now, option labels and values will be the same
        # Displays a comma delimited string of form_field_options for editing
        def options_string
          self.form_field_options.map {|ffo| ffo.label}.join(', ')
        end
        
        # for now, option labels and values will be the same
        # This is a virtual attribute for setting form_field_options with a comma delimited string
        def options_string=(str)
          self.form_field_options.delete_all
          arr = str.split(',')
          arr.each_with_index {|l, i| self.form_field_options.build(:label => l.strip, :value => l.strip, :position => i)}
        end
        
        def name
          self[:name]
        end
        
        def name_with_default
          orig = name_without_default
          if orig.blank?
            assign_name
            name_without_default
          else
            orig
          end
        end
        
        #overwritten by self.allow_validation_of
        def allow_validation_of?(sym)
          false
        end
        
        private
        
        def assign_name
          self.name = "field_" + Digest::SHA1.hexdigest(self.label + Time.now.to_s).first(20)
        end
        
      end
      
      module ClassMethods
        # indicates that the value of this field is an array of responses
        def has_many_responses
          define_method("has_many_responses?") { true }
        end
        
        # indicates there is a static set that can be used in a select, check_box_group, etc
        def acts_as_selector
          define_method("is_selector?") { true }
        end
        
        def allow_validation_of(*syms)
          define_method 'allow_validation_of?' do |sym|
            syms.include? sym
          end
        end
      end
      
    end
  end
end

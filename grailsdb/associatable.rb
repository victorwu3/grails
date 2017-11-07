require_relative '02_searchable'
require 'active_support/inflector'
module GrailedORM
  class AssocOptions
    attr_accessor(
      :foreign_key,
      :class_name,
      :primary_key
    )

    def model_class
      class_name.constantize
    end

    def table_name
      model_class.table_name
    end
  end

  class BelongsToOptions < AssocOptions
    def initialize(name, options = {})
      options[:primary_key] ||= :id
      options[:foreign_key] ||= "#{name}_id".to_sym
      options[:class_name] ||= "#{name}".camelcase

      @primary_key = options[:primary_key]
      @foreign_key = options[:foreign_key]
      @class_name = options[:class_name]


    end
  end

  class HasManyOptions < AssocOptions
    def initialize(name, self_class_name, options = {})
      @foreign_key = options[:foreign_key] || "#{self_class_name.downcase}_id".to_sym
      @class_name = options[:class_name] || name.to_s.singularize.camelcase
      @primary_key = options[:primary_key] || :id

    end
  end

  module Associatable
    def belongs_to(name, options = {})
      define_method(name) do
        assoc = BelongsToOptions.new(name, options)
        foreign_id = self.send(assoc.foreign_key)
        result = DBConnection.execute(<<-SQL, foreign_id)
        SELECT
        *
        FROM
        #{assoc.table_name}
        WHERE
        id = ?
        SQL

        assoc.model_class.parse_all(result).first
      end
    end


    def has_many(name, options = {})

      define_method(name) do
        assoc = HasManyOptions.new(name, self.class.to_s, options)
        foreign_id = self.send(assoc.primary_key)
        result = DBConnection.execute(<<-SQL, foreign_id)
        SELECT
        *
        FROM
        #{assoc.table_name}
        WHERE
        #{assoc.foreign_key} = ?
        SQL

        assoc.model_class.parse_all(result)
      end
    end

    def assoc_options
      @assoc_options ||= {}
    end

    def has_one_through(name, through_name, source_name)
      define_method(name) do
        through_options = self.class.assoc_options[through_name]
        source_options = through_options.model_class.assoc_options[source_name]

        through_table = through_options.table_name
        through_primary_key = through_options.primary_key
        through_foreign_key = through_options.foreign_key

        source_table = source_options.table_name
        source_primary_key = source_options.primary_key
        source_foreign_key = source_options.foreign_key

        key_val = self.send(through_foreign_key)
        results = DBConnection.execute(<<-SQL, key_val)
        SELECT
        #{source_table}.*
        FROM
        #{through_table}
        JOIN
        #{source_table}
        ON
        #{through_table}.#{source_foreign_key} = #{source_table}.#{source_primary_key}
        WHERE
        #{through_table}.#{through_primary_key} = ?
        SQL

        source_options.model_class.parse_all(results).first
      end
    end

    def has_many_through(name, through_name, source_name)
      define_method(name) do
        through_options = self.class.assoc_options[through_name]
        source_options = through_options.model_class.assoc_options[source_name]

        through_table = through_options.table_name
        through_primary_key = through_options.primary_key
        through_foreign_key = through_options.foreign_key

        source_table = source_options.table_name
        source_primary_key = source_options.primary_key
        source_foreign_key = source_options.foreign_key

        key_val = self.send(through_foreign_key)
        results = DBConnection.execute(<<-SQL, key_val)
        SELECT
        #{source_table}.*
        FROM
        #{through_table}
        JOIN
        #{source_table}
        ON
        #{through_table}.#{source_foreign_key} = #{source_table}.#{source_primary_key}
        WHERE
        #{through_table}.#{through_primary_key} = ?
        SQL

        source_options.model_class.parse_all(results)
      end
    end
  end
end

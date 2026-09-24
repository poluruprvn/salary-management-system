# Rails' date type casts an unparseable string to nil but passes a number or a boolean through
# uncast. Postgres then stores 20240101 as a date the model cannot compare, and a huge year fails the
# insert. Both cast to nil here, bounded to four digit years like as_of, so validation answers.
class StrictDateType < ActiveRecord::Type::Date
  private
    def cast_value(value)
      date = super if value.is_a?(::String) || value.respond_to?(:to_date)
      date if date.is_a?(::Date) && date.year.between?(1, 9999)
    end
end

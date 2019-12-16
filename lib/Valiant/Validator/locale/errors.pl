{
  en => {
    attributes => {
      retirement_date => 'Retires On',
    },
    errors => {
      messages => {
        # numericality
        not_less_than_or_equal_to => 'must be less than or equal to {{count}}',
        not_a_number => "is not a number",
        not_an_integer => "must be an integer",
        not_greater_than => "must be greater than {{count}}",
        not_greater_than_or_equal_to => "must be greater than or equal to {{count}}",
        not_equal_to => "must be equal to {{count}}",
        not_less_than => "must be less than {{count}}",
        not_other_than => "must be other than {{count}}",
        not_odd => "must be odd",
        not_even => "must be even",     
        # length
        too_short => {
          one => 'is too short (minimum is 1 character)',
          other => 'is too short (minimum is {{count}} characters',
        },
      },
    }
  },
};

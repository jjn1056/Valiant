{
  en => {
    attributes => {
      retirement_date => 'Retires On',
    },
    errors => {
      messages => {
        # numericality
        less_than_or_equal_to_err => 'must be less than or equal to {{count}}',
        is_number_err => "is not a number",
        is_integer_err => "must be an integer",
        greater_than_err => "must be greater than {{count}}",
        greater_than_or_equal_to_err => "must be greater than or equal to {{count}}",
        equal_to_err => "must be equal to {{count}}",
        less_than_err => "must be less than {{count}}",
        other_than_err => "must be other than {{count}}",
        odd_err => "must be odd",
        even_err => "must be even",     
        # length
        too_short => {
          one => 'is too short (minimum is 1 character)',
          other => 'is too short (minimum is {{count}} characters)',
        },
        too_long => {
          one => 'is too long (maximum is 1 character)',
          other => 'is too long (maximum is {{count}} characters)',
        },
        wrong_length => {
          one => "is the wrong length (should be 1 character)",
          other => "is the wrong length (should be {{count}} characters)",
        },
      },
    }
  },
};

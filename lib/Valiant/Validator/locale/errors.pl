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
        # presence
        is_blank => "can't be blank",
        # absence
        is_present => 'must be blank',
        # inclusion
        inclusion => 'is not in the list',
        # exclusion
        exclusion => 'is reserved',
        # format
        invalid_format_match => 'does not match the required pattern',
        invalid_format_without => 'contains invalid characters',
        # confirmation
        confirmation => "doesn't match '{{attribute}}'",
        #only_of
        only_of => {
          one => 'please choose only {{count}} field',
          other => 'please choose only {{count}} fields'
        },
        #check
        check => 'is invalid',
        #boolean
        is_not_true => 'must be a true value',
        is_not_false => 'must be a false value',
      },
    }
  },
};

function dataToHash(obj, prefix = '', flattened = {}) {
  for (let key in obj) {
    if (obj.hasOwnProperty(key)) {
      let propName = prefix ? prefix + '.' + key : key;

      if (typeof obj[key] === 'object' && obj[key] !== null) {
        if (Array.isArray(obj[key])) {
          for (let i = 0; i < obj[key].length; i++) {
            dataToHash(obj[key][i], propName + '[' + i + ']', flattened);
          }
        } else {
          dataToHash(obj[key], propName, flattened);
        }
      } else {
        flattened[propName] = obj[key];
      }
    }
  }
  return flattened;
}

function errorsToHash(array) {
  var hash = {};
  for (var i = 0; i < array.length; i++) {
    var item = array[i];
    hash[item.source.parameter] = item.detail;
  }
  return hash;
}


$(document).ready(function() {
  $("#edit_account").submit(function(event) {
    event.preventDefault(); // Prevent the default form submission

    var formData = $(this).serialize();
    var options = {
      method: "POST",
      headers: {
        "Accept": "application/json",
      },
      data: formData
    }; 

    // need to handle redirects correctly
    $.ajax(this.action, options)
      .done(function(response) {
        // Handle the response from the server
        var newFields = dataToHash(error.responseJSON.data);
        
      })
      .fail(function(error) {
        
        var fieldErrors = errorsToHash(error.responseJSON.errors);
        var newFields = dataToHash(error.responseJSON.data);

        console.log(fieldErrors);
        console.log(newFields);

        // loop over returned data, check to see if there's an error for that field
        // and if so use the error template, otherwise use the data template

        for (var fieldName in newFields) {
          var newFieldValue = newFields[fieldName];

          var fieldID = fieldName.replace(/\./g, "_"); // Replace all "." with "_"
          fieldID = fieldID.replace(/\]/g, ""); // Remove all "]"
          fieldID = fieldID.replace(/\[/g, "_"); // Replace all "[" with "_"
          
          var errors = fieldErrors[fieldName];
          if (errors) {
            var templateNode = document.getElementById(fieldID + '_template_error');
            if(!templateNode) {
              console.log("no error template for " + fieldID);
              continue;
            }

            var template = templateNode.innerHTML;
            var fieldNode = $(template);
            $(fieldNode).val(newFieldValue)

            console.log("xxxxxxxx errors for " + fieldID);
            console.log(template);
            console.log(fieldNode);

            $("#"+fieldID).replaceWith(fieldNode)

            var errorsForTemplate = document.getElementById(fieldID + '_template_errors_for_multi').innerHTML;
            var errorsForNode = $(errorsForTemplate);

            errorsForNode.find("[data-error-param='1']").each(function(index) {
              var $currentElement = $(this);
              var parent = $(this).parent();
              var $messageTemplate = $currentElement.clone();
              $currentElement.remove();

              for (var i = 0; i < errors.length; i++) {
                var $message = $messageTemplate.clone();
                $message.html(errors[i]);
                parent.append($message);
              }
            });
            $("#"+fieldID+"_errors_for_target").replaceWith(errorsForNode);
          } else {
            console.log("no errors for " + fieldID);
            var templateNode = document.getElementById(fieldID + '_template');
            if(!templateNode) {
              console.log("no template for " + fieldID);
              continue;
            }
            var fieldNode = $(templateNode.innerHTML);
            $(fieldNode).val(newFieldValue)
            $("#"+fieldID).replaceWith(fieldNode)
          }
        }
      });
  });
});
$(document).ready(function() {
  $('[data-remote="true"]').submit(function(event) {
    event.preventDefault();

    // get the form fields
    var submittedButton = $(this).find(':submit:focus'); // Get the focused submit button
    var buttonName = submittedButton.attr('name'); // Retrieve the name attribute
    var buttonValue = submittedButton.val(); // Retrieve the value

    // Serialize the form data and append the button name and value
    var formData = $(this).serialize();
    formData += '&' + encodeURIComponent(buttonName) + '=' + encodeURIComponent(buttonValue);

    var options = {
      method: "POST",
      dataType: "script",
      cache: false,
      headers: {  
        "Accept": "application/javascript",
      },
      data: formData,
    };

    $.ajax(this.action, options)
    .done(function(response) {
      // Handle the response from the server
      console.log(response);
      var customEvent = document.createEvent('CustomEvent');
      customEvent.initCustomEvent('ajaxSuccess', true, true, { message: 'Custom event triggered' });

      // Dispatch the custom event
      document.dispatchEvent(customEvent);
    })
    .fail(function(error) {
      // Handle errors
      console.log(error);
      console.log(error.responseText);
      // There needs to be some way to determine if this is an error error
      // or if there's actally a viable payload.  for example you might return
      // a 400 bad request for a validation error, but still want to render
      // the form with the errors.
      var script = document.createElement("script");
      script.text = error.responseText;
      document.head.appendChild(script).parentNode.removeChild(script);

      var customEvent = document.createEvent('CustomEvent');
      customEvent.initCustomEvent('ajaxSuccess', true, true, { message: 'Custom event triggered' });

      // Dispatch the custom event
      document.dispatchEvent(customEvent);

    });

  });
});

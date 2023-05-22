$(document).ready(function() {
  $("#edit_account").submit(function(event) {
    event.preventDefault(); // Prevent the default form submission

    var formData = $(this).serialize();
    console.log(formData);

    /* Get form data
    let JSONData = $(this).serializeJSON();
    console.log(JSONData);

    // Send JSON data to the server (AJAX, fetch, etc.)
    let csrf_token = JSONData['csrf_token'];
    delete JSONData['csrf_token'];
    let options = {
      method: "POST",
      headers: {
        "X-CSRF-Token": csrf_token,
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      data: JSON.stringify(JSONData)
    };*/

    var options = {
      method: "POST",
      headers: {
        "Accept": "application/json",
      },
      data: formData
    }; 

    $.ajax(this.action, options)
      .done(function(response) {
        // Handle the response from the server
        console.log(response.responseJSON);
      })
      .fail(function(error) {
        // Handle errors
        console.error(error.responseJSON);
    });
  });
});
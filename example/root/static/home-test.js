var callingObject;
$(document).ready(function() {
  $('[data-remote="true"]').click(function(event) {
    event.preventDefault();
    callingObject = this;
    // Load the script using getScript()
    $.getScript($(this).attr('formaction'))
      .done(function() {
        testRemote();
      })
      .fail(function(jqxhr, settings, exception) {
        // Error handling if the script fails to load
      });
  });
});

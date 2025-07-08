document.getElementById('supportForm').addEventListener('submit', function(e) {
  e.preventDefault(); // Stop form from refreshing

  const name = document.getElementById('name').value;
  const issue = document.getElementById('issue').value;

  document.getElementById('responseMessage').innerText = 
    `Thank you, ${name}. Your support request has been received. We will respond shortly.`;

  // Optional: Clear form
  this.reset();
});

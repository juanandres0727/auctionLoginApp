<%@ page contentType="text/html; charset=UTF-8" %>
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Auction Login</title>
</head>
<body>
  <h1>Auction Site Login</h1>
  <h3>Login</h3>

  <form method="post" action="login.jsp">
    <label>
      Username:
      <input type="text" name="username" required>
    </label>
    <br/><br/>

    <label>
      Password:
      <input type="password" name="password" required>
    </label>
    <br/><br/>

    <button type="submit">Log In</button>
  </form>

  <br/>

  <p>Don't have an account? <a href="register.jsp">Create one here</a></p>
</body>
</html>
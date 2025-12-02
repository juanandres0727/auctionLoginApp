<%@ page import="java.sql.*,java.util.Properties,java.io.FileInputStream" %>
<%@ page contentType="text/html; charset=UTF-8" %>
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Register</title>
</head>
<body>
<%
String method = request.getMethod();

if ("GET".equalsIgnoreCase(method)) {
  //Show registration form
%>
  <h2>Create Account</h2>
  <form method="post" action="register.jsp">
    <label>
      Username:
      <input type="text" name="username" required>
    </label>
    <br/><br/>

    <label>
      E-mail:
      <input type="email" name="email" required>
    </label>
    <br/><br/>

    <label>
      Password:
      <input type="password" name="password" required>
    </label>
    <br/><br/>

    <button type="submit">Register</button>
  </form>

  <p>Already have an account? <a href="index.jsp">Back to login</a></p>

<%
} else {
  //Handle form submit (POST)
  request.setCharacterEncoding("UTF-8");
  String username = request.getParameter("username");
  String email    = request.getParameter("email");
  String password = request.getParameter("password");

  boolean ok = false;
  String message = "";

  if (username == null || email == null || password == null ||
      username.isEmpty() || email.isEmpty() || password.isEmpty()) {
    message = "All fields are required.";
  } else {
    try {
      //Load DB properties
      Properties props = new Properties();
      String propsPath = application.getRealPath("/WEB-INF/db.properties");
      try (FileInputStream fis = new FileInputStream(propsPath)) {
        props.load(fis);
      }

      String url  = props.getProperty("db.url");
      String user = props.getProperty("db.user");
      String pass = props.getProperty("db.password");

      Class.forName("com.mysql.cj.jdbc.Driver");

      //Insert new user; store hash as SHA2(password,256) in db
      try (Connection c = DriverManager.getConnection(url, user, pass);
           PreparedStatement ps = c.prepareStatement(
             "INSERT INTO users (username, email, password_hash, role, active) " +
             "VALUES (?, ?, SHA2(?,256), 'END_USER', 1)")) {

        ps.setString(1, username);
        ps.setString(2, email);
        ps.setString(3, password);
        ps.executeUpdate();
        ok = true;
      }
    } catch (SQLIntegrityConstraintViolationException e) {
      //username is UNIQUE in your table
      message = "Username already exists. Please choose another.";
    } catch (Exception e) {
      message = "Error creating account: " + e.getMessage();
    }
  }

  if (ok) {
%>
  <h2>Account created</h2>
  <p>You can now log in as <strong><%= username %></strong>.</p>
  <p><a href="index.jsp">Go to login</a></p>
<%
  } else {
%>
  <h2>Registration failed</h2>
  <p><%= message %></p>
  <p><a href="register.jsp">Try again</a></p>
  <p><a href="index.jsp">Back to login</a></p>
<%
  }
} // end POST
%>
</body>
</html>
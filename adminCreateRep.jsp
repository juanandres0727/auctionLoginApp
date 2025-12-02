<%@ page import="java.sql.*,java.util.Properties,java.io.FileInputStream" %>
<%@ page contentType="text/html; charset=UTF-8" %>

<%
    // Require admin login
    String username = (String) session.getAttribute("username");
    String role     = (String) session.getAttribute("role");
    if (username == null || role == null || !"ADMIN".equals(role)) {
        response.sendRedirect("home.jsp?msg=Access+Denied");
        return;
    }

    request.setCharacterEncoding("UTF-8");

    String msg = null;

    // Handle form submission (POST)
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String newUser = request.getParameter("new_username");
        String pw1     = request.getParameter("new_password");
        String pw2     = request.getParameter("confirm_password");

        if (newUser == null || newUser.trim().isEmpty()
            || pw1 == null || pw1.isEmpty()
            || pw2 == null || pw2.isEmpty()) {

            msg = "All fields are required.";
        } else if (!pw1.equals(pw2)) {
            msg = "Passwords do not match.";
        } else {
            // Load DB properties
            try {
                Properties props = new Properties();
                String propsPath = application.getRealPath("/WEB-INF/db.properties");
                try (FileInputStream fis = new FileInputStream(propsPath)) {
                    props.load(fis);
                }
                String url    = props.getProperty("db.url");
                String dbUser = props.getProperty("db.user");
                String dbPass = props.getProperty("db.password");
                Class.forName("com.mysql.cj.jdbc.Driver");

                try (Connection c = DriverManager.getConnection(url, dbUser, dbPass)) {
                    String sql =
                      "INSERT INTO users (username, password_hash, role) " +
                      "VALUES (?, SHA2(?,256), 'REP')";

                    try (PreparedStatement ps = c.prepareStatement(sql)) {
                        ps.setString(1, newUser.trim());
                        ps.setString(2, pw1);
                        ps.executeUpdate();
                        msg = "Customer representative account created for username: " + newUser.trim();
                    } catch (java.sql.SQLIntegrityConstraintViolationException dup) {
                        msg = "Username '" + newUser.trim() + "' is already taken.";
                    }
                }
            } catch (Exception e) {
                msg = "Error creating representative: " + e.getMessage();
            }
        }
    }
%>
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Create Customer Representative</title>
</head>
<body>
  <h2>Create Customer Representative Account</h2>
  <p>Logged in as <strong><%= username %></strong> (ADMIN)</p>

<% if (msg != null) { %>
  <p style="color:blue;"><%= msg %></p>
<% } %>

  <form method="post" action="adminCreateRep.jsp">
    <p>
      <label>New REP username:
        <input type="text" name="new_username" required>
      </label>
    </p>

    <p>
      <label>Password:
        <input type="password" name="new_password" required>
      </label>
    </p>

    <p>
      <label>Confirm password:
        <input type="password" name="confirm_password" required>
      </label>
    </p>

    <p>
      <button type="submit">Create REP account</button>
    </p>
  </form>

  <p><a href="adminDashboard.jsp">Back to Admin Dashboard</a></p>
  <p><a href="home.jsp">Back to Home</a></p>
</body>
</html>
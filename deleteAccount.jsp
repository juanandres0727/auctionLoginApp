<%@ page import="java.sql.*,java.util.Properties,java.io.FileInputStream" %>
<%@ page contentType="text/html; charset=UTF-8" %>

<%
    // Require login
    Integer userIdObj = (Integer) session.getAttribute("user_id");
    String username   = (String) session.getAttribute("username");
    String role       = (String) session.getAttribute("role");

    if (userIdObj == null || username == null) {
        response.sendRedirect("index.jsp?msg=Please+login");
        return;
    }
    int userId = userIdObj;

    // Load DB properties
    Properties props = new Properties();
    String propsPath = application.getRealPath("/WEB-INF/db.properties");
    try (FileInputStream fis = new FileInputStream(propsPath)) {
        props.load(fis);
    }
    String url    = props.getProperty("db.url");
    String dbUser = props.getProperty("db.user");
    String dbPass = props.getProperty("db.password");

    Class.forName("com.mysql.cj.jdbc.Driver");

    String method = request.getMethod();
    String msg    = null;
    boolean deleted = false;

    if ("POST".equalsIgnoreCase(method)) {
        String confirm = request.getParameter("confirm_text");
        if (confirm == null || !confirm.trim().equals("DELETE")) {
            msg = "You must type DELETE exactly to confirm.";
        } else {
            // Perform deletion
            try (Connection c = DriverManager.getConnection(url, dbUser, dbPass)) {
                c.setAutoCommit(false);

                // Delete data for auctions the user is selling
                // Delete auto_bids on those auctions
                try (PreparedStatement ps = c.prepareStatement(
                     "DELETE FROM auto_bids " +
                     "WHERE auction_id IN (SELECT auction_id FROM auctions WHERE seller_id = ?)")) {
                    ps.setInt(1, userId);
                    ps.executeUpdate();
                }

                // Delete bids on those auctions
                try (PreparedStatement ps = c.prepareStatement(
                     "DELETE FROM bids " +
                     "WHERE auction_id IN (SELECT auction_id FROM auctions WHERE seller_id = ?)")) {
                    ps.setInt(1, userId);
                    ps.executeUpdate();
                }

                // Delete the auctions themselves
                try (PreparedStatement ps = c.prepareStatement(
                     "DELETE FROM auctions WHERE seller_id = ?")) {
                    ps.setInt(1, userId);
                    ps.executeUpdate();
                }

                // Delete alerts created by this user
                try (PreparedStatement ps = c.prepareStatement(
                     "DELETE FROM alerts WHERE user_id = ?")) {
                    ps.setInt(1, userId);
                    ps.executeUpdate();
                }

                // Delete auto_bids where this user is the bidder
                try (PreparedStatement ps = c.prepareStatement(
                     "DELETE FROM auto_bids WHERE bidder_id = ?")) {
                    ps.setInt(1, userId);
                    ps.executeUpdate();
                }

                // Delete bids placed by this user (on others' auctions)
                try (PreparedStatement ps = c.prepareStatement(
                     "DELETE FROM bids WHERE bidder_id = ?")) {
                    ps.setInt(1, userId);
                    ps.executeUpdate();
                }

                // Finally delete the user
                try (PreparedStatement ps = c.prepareStatement(
                     "DELETE FROM users WHERE user_id = ?")) {
                    ps.setInt(1, userId);
                    ps.executeUpdate();
                }

                c.commit();
                deleted = true;
                session.invalidate();  // log them out
            } catch (Exception e) {
                msg = "Error deleting account: " + e.getMessage();
            }
        }
    }
%>
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Delete My Account</title>
</head>
<body>
<% if (!deleted) { %>
  <h2>Delete My Account</h2>
  <p>You are logged in as <strong><%= username %></strong> (role: <%= role %>).</p>

  <% if (msg != null) { %>
    <p style="color:red;"><%= msg %></p>
  <% } %>

  <p>
    Deleting your account will:
  </p>
  <ul>
    <li>Remove all your auctions (and bids on them).</li>
    <li>Remove all bids you have placed.</li>
    <li>Remove all alerts and auto-bids associated with your account.</li>
    <li>Permanently remove your user record.</li>
  </ul>

  <form method="post" action="deleteAccount.jsp">
    <p>
      Type <code>DELETE</code> to confirm:<br/>
      <input type="text" name="confirm_text" />
    </p>
    <button type="submit">Yes, delete my account</button>
  </form>

  <p><a href="home.jsp">Cancel and go back home</a></p>

<% } else { %>
  <h2>Account deleted</h2>
  <p>Your account and associated data have been deleted.</p>
  <p><a href="index.jsp">Return to login page</a></p>
<% } %>
</body>
</html>
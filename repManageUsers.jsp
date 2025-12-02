<%@ page import="java.sql.*,java.util.Properties,java.io.FileInputStream" %>
<%@ page contentType="text/html; charset=UTF-8" %>

<%
    //Require REP (you can allow ADMIN too if you want)
    String username = (String) session.getAttribute("username");
    String role     = (String) session.getAttribute("role");
    Integer repIdObj = (Integer) session.getAttribute("user_id");

    if (username == null || role == null || !"REP".equals(role)) {
        response.sendRedirect("home.jsp?msg=Access+Denied");
        return;
    }
    int repId = repIdObj;

    //Load db properties
    Properties props = new Properties();
    String propsPath = application.getRealPath("/WEB-INF/db.properties");
    try (FileInputStream fis = new FileInputStream(propsPath)) {
        props.load(fis);
    }
    String url    = props.getProperty("db.url");
    String dbUser = props.getProperty("db.user");
    String dbPass = props.getProperty("db.password");

    Class.forName("com.mysql.cj.jdbc.Driver");

    String action = request.getParameter("action");
    String msg    = null;

    //Handle actions: reset_password, update_user, delete_user, answer_question
    if (action != null) {
        try (Connection c = DriverManager.getConnection(url, dbUser, dbPass)) {
            c.setAutoCommit(false);

            try {
                if ("reset_password".equals(action)) {
                    String targetIdStr = request.getParameter("user_id");
                    int targetId = Integer.parseInt(targetIdStr);

                    // Get target user & role
                    String targetUser = null;
                    String targetRole = null;
                    try (PreparedStatement ps = c.prepareStatement(
                         "SELECT username, role FROM users WHERE user_id = ?")) {
                        ps.setInt(1, targetId);
                        try (ResultSet rs = ps.executeQuery()) {
                            if (rs.next()) {
                                targetUser = rs.getString("username");
                                targetRole = rs.getString("role");
                            }
                        }
                    }

                    if (targetUser == null) {
                        msg = "User not found.";
                    } else if ("ADMIN".equals(targetRole)) {
                        msg = "You cannot reset the ADMIN password.";
                    } else {
                        String tempPass = "Temp123!";
                        try (PreparedStatement ps = c.prepareStatement(
                             "UPDATE users SET password_hash = SHA2(?,256) WHERE user_id = ?")) {
                            ps.setString(1, tempPass);
                            ps.setInt(2, targetId);
                            ps.executeUpdate();
                        }
                        msg = "Password for user '" + targetUser + "' has been reset to Temp123!.";
                    }

                } else if ("update_user".equals(action)) {
                    String targetIdStr  = request.getParameter("user_id");
                    String newUsername  = request.getParameter("new_username");
                    int targetId        = Integer.parseInt(targetIdStr);

                    if (newUsername == null || newUsername.trim().isEmpty()) {
                        msg = "New username cannot be empty.";
                    } else {
                        // Check role – do not modify ADMIN
                        String targetRole = null;
                        try (PreparedStatement ps = c.prepareStatement(
                             "SELECT role FROM users WHERE user_id = ?")) {
                            ps.setInt(1, targetId);
                            try (ResultSet rs = ps.executeQuery()) {
                                if (rs.next()) {
                                    targetRole = rs.getString("role");
                                }
                            }
                        }
                        if (targetRole == null) {
                            msg = "User not found.";
                        } else if ("ADMIN".equals(targetRole)) {
                            msg = "You cannot modify the ADMIN account.";
                        } else {
                            try (PreparedStatement ps = c.prepareStatement(
                                 "UPDATE users SET username = ? WHERE user_id = ?")) {
                                ps.setString(1, newUsername.trim());
                                ps.setInt(2, targetId);
                                ps.executeUpdate();
                            }
                            msg = "Username updated to '" + newUsername.trim() + "'.";
                        }
                    }

                } else if ("delete_user".equals(action)) {
                    String targetIdStr = request.getParameter("user_id");
                    int targetId       = Integer.parseInt(targetIdStr);

                    //Cannot delete yourself or admin
                    if (targetId == repId) {
                        msg = "You cannot delete your own account.";
                    } else {
                        String targetUser = null;
                        String targetRole = null;
                        try (PreparedStatement ps = c.prepareStatement(
                             "SELECT username, role FROM users WHERE user_id = ?")) {
                            ps.setInt(1, targetId);
                            try (ResultSet rs = ps.executeQuery()) {
                                if (rs.next()) {
                                    targetUser = rs.getString("username");
                                    targetRole = rs.getString("role");
                                }
                            }
                        }

                        if (targetUser == null) {
                            msg = "User not found.";
                        } else if ("ADMIN".equals(targetRole)) {
                            msg = "You cannot delete the ADMIN account.";
                        } else {
                            //Delete data similar to deleteAccount.jsp
                            //auto_bids on auctions this user is selling
                            try (PreparedStatement ps = c.prepareStatement(
                                 "DELETE FROM auto_bids " +
                                 "WHERE auction_id IN (SELECT auction_id FROM auctions WHERE seller_id = ?)")) {
                                ps.setInt(1, targetId);
                                ps.executeUpdate();
                            }

                            //bids on those auctions
                            try (PreparedStatement ps = c.prepareStatement(
                                 "DELETE FROM bids " +
                                 "WHERE auction_id IN (SELECT auction_id FROM auctions WHERE seller_id = ?)")) {
                                ps.setInt(1, targetId);
                                ps.executeUpdate();
                            }

                            //delete those auctions
                            try (PreparedStatement ps = c.prepareStatement(
                                 "DELETE FROM auctions WHERE seller_id = ?")) {
                                ps.setInt(1, targetId);
                                ps.executeUpdate();
                            }

                            //alerts created by user
                            try (PreparedStatement ps = c.prepareStatement(
                                 "DELETE FROM alerts WHERE user_id = ?")) {
                                ps.setInt(1, targetId);
                                ps.executeUpdate();
                            }

                            //auto_bids placed by user
                            try (PreparedStatement ps = c.prepareStatement(
                                 "DELETE FROM auto_bids WHERE bidder_id = ?")) {
                                ps.setInt(1, targetId);
                                ps.executeUpdate();
                            }

                            //bids placed by user
                            try (PreparedStatement ps = c.prepareStatement(
                                 "DELETE FROM bids WHERE bidder_id = ?")) {
                                ps.setInt(1, targetId);
                                ps.executeUpdate();
                            }

                            //questions asked by user
                            try (PreparedStatement ps = c.prepareStatement(
                                 "DELETE FROM questions WHERE asker_id = ?")) {
                                ps.setInt(1, targetId);
                                ps.executeUpdate();
                            }

                            //finally delete user
                            try (PreparedStatement ps = c.prepareStatement(
                                 "DELETE FROM users WHERE user_id = ?")) {
                                ps.setInt(1, targetId);
                                ps.executeUpdate();
                            }

                            msg = "User '" + targetUser + "' and their related data have been deleted.";
                        }
                    }

                } else if ("answer_question".equals(action)) {
                    String qIdStr = request.getParameter("question_id");
                    String answer = request.getParameter("answer_text");
                    int qId = Integer.parseInt(qIdStr);

                    if (answer == null || answer.trim().isEmpty()) {
                        msg = "Answer text cannot be empty.";
                    } else {
                        try (PreparedStatement ps = c.prepareStatement(
                             "UPDATE questions " +
                             "SET answer_text = ?, answered_at = NOW(), answered_by = ? " +
                             "WHERE question_id = ?")) {
                            ps.setString(1, answer.trim());
                            ps.setInt(2, repId);
                            ps.setInt(3, qId);
                            int updated = ps.executeUpdate();
                            if (updated > 0) {
                                msg = "Answer saved.";
                            } else {
                                msg = "Question not found.";
                            }
                        }
                    }
                }

                c.commit();
            } catch (Exception inner) {
                c.rollback();
                if (msg == null) msg = "Error: " + inner.getMessage();
            }
        } catch (Exception outer) {
            if (msg == null) msg = "DB error: " + outer.getMessage();
        }
    }

    String searchUsername = request.getParameter("search_username");
%>
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>REP – Manage Users & Questions</title>
</head>
<body>
  <h2>REP – Manage Users & Questions</h2>
  <p>Logged in as <strong><%= username %></strong> (REP)</p>

  <% if (msg != null) { %>
    <p style="color:blue;"><%= msg %></p>
  <% } %>

  <hr/>

  <!-- user loopkup + edit, reset, and delete -->
  <h3>User Lookup, Edit & Password Reset</h3>

  <form method="get" action="repManageUsers.jsp">
    <label>Search by username (partial allowed):
      <input type="text" name="search_username"
             value="<%= (searchUsername == null ? "" : searchUsername) %>">
    </label>
    <button type="submit">Search</button>
  </form>

  <table border="1" cellpadding="4" cellspacing="0" style="margin-top:10px;">
    <tr>
      <th>User ID</th>
      <th>Username</th>
      <th>Role</th>
      <th>Created</th>
      <th>Actions</th>
    </tr>
<%
    try (Connection c = DriverManager.getConnection(url, dbUser, dbPass)) {
        String sql = "SELECT user_id, username, role, created_at FROM users";
        if (searchUsername != null && !searchUsername.trim().isEmpty()) {
            sql += " WHERE username LIKE ?";
        }
        sql += " ORDER BY username ASC LIMIT 50";

        try (PreparedStatement ps = c.prepareStatement(sql)) {
            if (searchUsername != null && !searchUsername.trim().isEmpty()) {
                ps.setString(1, "%" + searchUsername.trim() + "%");
            }

            try (ResultSet rs = ps.executeQuery()) {
                boolean any = false;
                while (rs.next()) {
                    any = true;
                    int uid = rs.getInt("user_id");
                    String u = rs.getString("username");
                    String r = rs.getString("role");
%>
    <tr>
      <td><%= uid %></td>
      <td><%= u %></td>
      <td><%= r %></td>
      <td><%= rs.getTimestamp("created_at") %></td>
      <td>
        <% if ("ADMIN".equals(r)) { %>
          (cannot modify ADMIN)
        <% } else { %>
          <!-- Reset password -->
          <form method="post" action="repManageUsers.jsp" style="display:inline;">
            <input type="hidden" name="action" value="reset_password">
            <input type="hidden" name="user_id" value="<%= uid %>">
            <button type="submit">Reset password</button>
          </form>

          <!-- Update username -->
          <form method="post" action="repManageUsers.jsp" style="display:inline;">
            <input type="hidden" name="action" value="update_user">
            <input type="hidden" name="user_id" value="<%= uid %>">
            <input type="text" name="new_username" size="10" placeholder="new username">
            <button type="submit">Update</button>
          </form>

          <!-- Delete user -->
          <form method="post" action="repManageUsers.jsp" style="display:inline;"
                onsubmit="return confirm('Are you sure you want to delete this user and all related data?');">
            <input type="hidden" name="action" value="delete_user">
            <input type="hidden" name="user_id" value="<%= uid %>">
            <button type="submit">Delete</button>
          </form>
        <% } %>
      </td>
    </tr>
<%
                }
                if (!any) {
%>
    <tr><td colspan="5"><em>No users found.</em></td></tr>
<%
                }
            }
        }
    } catch (Exception e) {
%>
    <tr><td colspan="5">Error loading users: <%= e.getMessage() %></td></tr>
<%
    }
%>
  </table>

  <hr/>

  <!-- Questions-->
  <h3>Unanswered Questions</h3>
  <table border="1" cellpadding="4" cellspacing="0">
    <tr>
      <th>ID</th>
      <th>Auction</th>
      <th>Asker</th>
      <th>Asked At</th>
      <th>Question</th>
      <th>Answer</th>
    </tr>
<%
    try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
         PreparedStatement ps = c.prepareStatement(
           "SELECT q.question_id, q.auction_id, q.question_text, q.asked_at, " +
           "u.username AS asker_name, a.title AS auction_title " +
           "FROM questions q " +
           "JOIN users u ON q.asker_id = u.user_id " +
           "JOIN auctions a ON q.auction_id = a.auction_id " +
           "WHERE q.answer_text IS NULL " +
           "ORDER BY q.asked_at ASC")) {

        try (ResultSet rs = ps.executeQuery()) {
            boolean any = false;
            while (rs.next()) {
                any = true;
%>
    <tr>
      <td><%= rs.getInt("question_id") %></td>
      <td>#<%= rs.getInt("auction_id") %> - <%= rs.getString("auction_title") %></td>
      <td><%= rs.getString("asker_name") %></td>
      <td><%= rs.getTimestamp("asked_at") %></td>
      <td><%= rs.getString("question_text") %></td>
      <td>
        <form method="post" action="repManageUsers.jsp">
          <input type="hidden" name="action" value="answer_question">
          <input type="hidden" name="question_id" value="<%= rs.getInt("question_id") %>">
          <textarea name="answer_text" rows="3" cols="40"></textarea><br/>
          <button type="submit">Save answer</button>
        </form>
      </td>
    </tr>
<%
            }
            if (!any) {
%>
    <tr><td colspan="6"><em>No unanswered questions.</em></td></tr>
<%
            }
        }
    } catch (Exception e) {
%>
    <tr><td colspan="6">Error loading questions: <%= e.getMessage() %></td></tr>
<%
    }
%>
  </table>

  <h3>Recently Answered Questions</h3>
  <table border="1" cellpadding="4" cellspacing="0">
    <tr>
      <th>ID</th>
      <th>Auction</th>
      <th>Asker</th>
      <th>Asked At</th>
      <th>Answer</th>
      <th>Answered At</th>
    </tr>
<%
    try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
         PreparedStatement ps = c.prepareStatement(
           "SELECT q.question_id, q.auction_id, q.question_text, q.answer_text, " +
           "q.asked_at, q.answered_at, " +
           "u.username AS asker_name, a.title AS auction_title " +
           "FROM questions q " +
           "JOIN users u ON q.asker_id = u.user_id " +
           "JOIN auctions a ON q.auction_id = a.auction_id " +
           "WHERE q.answer_text IS NOT NULL " +
           "ORDER BY q.answered_at DESC LIMIT 20")) {

        try (ResultSet rs = ps.executeQuery()) {
            boolean any = false;
            while (rs.next()) {
                any = true;
%>
    <tr>
      <td><%= rs.getInt("question_id") %></td>
      <td>#<%= rs.getInt("auction_id") %> - <%= rs.getString("auction_title") %></td>
      <td><%= rs.getString("asker_name") %></td>
      <td><%= rs.getTimestamp("asked_at") %></td>
      <td><%= rs.getString("answer_text") %></td>
      <td><%= rs.getTimestamp("answered_at") %></td>
    </tr>
<%
            }
            if (!any) {
%>
    <tr><td colspan="6"><em>No answered questions yet.</em></td></tr>
<%
            }
        }
    } catch (Exception e) {
%>
    <tr><td colspan="6">Error loading answered questions: <%= e.getMessage() %></td></tr>
<%
    }
%>
  </table>

  <p><a href="repDashboard.jsp">REP Dashboard</a> | <a href="home.jsp">Home</a></p>
</body>
</html>
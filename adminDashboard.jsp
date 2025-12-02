<%@ page import="java.sql.*,java.util.Properties,java.io.FileInputStream" %>
<%@ page contentType="text/html; charset=UTF-8" %>

<%
    // Require admin login
    String username = (String) session.getAttribute("username");
    String role     = (String) session.getAttribute("role");
    Integer userIdObj = (Integer) session.getAttribute("user_id");

    if (username == null || role == null || !role.equals("ADMIN")) {
        response.sendRedirect("home.jsp?msg=Access+Denied");
        return;
    }

    int adminId = userIdObj;

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

    //Handle role-change actions (promote/demote)
    String action = request.getParameter("action");
    String targetIdStr = request.getParameter("user_id");
    String msg = null;

    if (action != null && targetIdStr != null) {
        try (Connection c = DriverManager.getConnection(url, dbUser, dbPass)) {
            int targetId = Integer.parseInt(targetIdStr);

            if (targetId == adminId) {
                msg = "You cannot modify your own role.";
            } else if ("make_rep".equals(action)) {
                try (PreparedStatement ps = c.prepareStatement(
                     "UPDATE users SET role='REP' WHERE user_id=?")) {
                    ps.setInt(1, targetId);
                    ps.executeUpdate();
                }
                msg = "User promoted to REP.";
            } else if ("make_end_user".equals(action)) {
                try (PreparedStatement ps = c.prepareStatement(
                     "UPDATE users SET role='END_USER' WHERE user_id=?")) {
                    ps.setInt(1, targetId);
                    ps.executeUpdate();
                }
                msg = "User demoted to END_USER.";
            }
        } catch (Exception e) {
            msg = "Error: " + e.getMessage();
        }
    }
%>

<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Admin Dashboard</title>
</head>
<body>

<h2>Admin Dashboard</h2>
<p>Logged in as <strong><%= username %></strong> (ADMIN)</p>

<% if (msg != null) { %>
  <p style="color:blue;"><%= msg %></p>
<% } %>

<hr/>

<h3>System Statistics</h3>
<table border="1" cellpadding="4">
<tr><th>Metric</th><th>Value</th></tr>

<%
    try (Connection c = DriverManager.getConnection(url, dbUser, dbPass)) {

        //Total Users
        try (Statement st = c.createStatement();
             ResultSet rs = st.executeQuery("SELECT COUNT(*) FROM users")) {
            rs.next();
%>
<tr><td>Total Users</td><td><%= rs.getInt(1) %></td></tr>
<%
        }

        //Total Auctions
        try (Statement st = c.createStatement();
             ResultSet rs = st.executeQuery("SELECT COUNT(*) FROM auctions")) {
            rs.next();
%>
<tr><td>Total Auctions</td><td><%= rs.getInt(1) %></td></tr>
<%
        }

        //Open auctions
        try (Statement st = c.createStatement();
             ResultSet rs = st.executeQuery("SELECT COUNT(*) FROM auctions WHERE status='OPEN'")) {
            rs.next();
%>
<tr><td>Open Auctions</td><td><%= rs.getInt(1) %></td></tr>
<%
        }

        //Closed auctions
        try (Statement st = c.createStatement();
             ResultSet rs = st.executeQuery("SELECT COUNT(*) FROM auctions WHERE status='CLOSED'")) {
            rs.next();
%>
<tr><td>Closed Auctions</td><td><%= rs.getInt(1) %></td></tr>
<%
        }

        //Total Bids
        try (Statement st = c.createStatement();
             ResultSet rs = st.executeQuery("SELECT COUNT(*) FROM bids")) {
            rs.next();
%>
<tr><td>Total Bids</td><td><%= rs.getInt(1) %></td></tr>
<%
        }

        //Total Auto-bids
        try (Statement st = c.createStatement();
             ResultSet rs = st.executeQuery("SELECT COUNT(*) FROM auto_bids")) {
            rs.next();
%>
<tr><td>Total Auto-Bids</td><td><%= rs.getInt(1) %></td></tr>
<%
        }

        /* 
           Uses sum of final (current_price) of closed auctions
        */
        try (Statement st = c.createStatement();
             ResultSet rs = st.executeQuery(
                 "SELECT COALESCE(SUM(current_price), 0) FROM auctions WHERE status='CLOSED'")) {
            rs.next();
%>
<tr><td><strong>Total Earnings (CLOSED auctions)</strong></td>
<td><strong><%= rs.getBigDecimal(1) %></strong></td></tr>
<%
        }

    } catch (Exception e) {
%>
<tr><td colspan="2">Error loading stats: <%= e.getMessage() %></td></tr>
<%
    }
%>
</table>

<hr/>

<h3>User Management</h3>
<table border="1" cellpadding="4" cellspacing="0">
<tr>
  <th>User ID</th>
  <th>Username</th>
  <th>Role</th>
  <th>Created At</th>
  <th>Actions</th>
</tr>

<%
try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
     Statement st = c.createStatement();
     ResultSet rs = st.executeQuery("SELECT user_id, username, role, created_at FROM users ORDER BY user_id ASC")) {

    while (rs.next()) {
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
    <% if (uid == adminId) { %>
        (your account)
    <% } else if ("END_USER".equals(r)) { %>
        <a href="adminDashboard.jsp?action=make_rep&user_id=<%= uid %>">Make REP</a>
    <% } else if ("REP".equals(r)) { %>
        <a href="adminDashboard.jsp?action=make_end_user&user_id=<%= uid %>">Make END_USER</a>
    <% } else { %>
        (no actions)
    <% } %>
  </td>
</tr>
<%
    }

} catch (Exception e) {
%>
<tr><td colspan="5">Error loading users: <%= e.getMessage() %></td></tr>
<%
}
%>

</table>

<hr/>

<h3>Reports</h3>
<ul>
  <li><a href="topSellers.jsp">Top Sellers Report</a></li>
  <li><a href="topBidders.jsp">Top Bidders Report</a></li>
  <li><a href="categoryReport.jsp">Category Performance Report</a></li>
  <li><a href="auctionActivity.jsp">Auction Activity Report</a></li>
  <li><a href="adminReports.jsp">View system reports</a></li>
  <li><a href="bestItems.jsp"><strong>Best-Selling Items (Earnings per Item)</strong></a></li>
</ul>

<p><a href="maintenance.jsp">Run maintenance (close expired auctions)</a></p>
<p><a href="home.jsp">Back to Home</a></p>

</body>
</html>
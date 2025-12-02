<%@ page import="java.sql.*,java.util.Properties,java.io.FileInputStream" %>
<%@ page contentType="text/html; charset=UTF-8" %>

<%
    String username = (String) session.getAttribute("username");
    String role     = (String) session.getAttribute("role");

    if (username == null || role == null || !"ADMIN".equals(role)) {
        response.sendRedirect("home.jsp?msg=Access+Denied");
        return;
    }

    Properties props = new Properties();
    String propsPath = application.getRealPath("/WEB-INF/db.properties");
    try (FileInputStream fis = new FileInputStream(propsPath)) {
        props.load(fis);
    }
    String url = props.getProperty("db.url");
    String dbUser = props.getProperty("db.user");
    String dbPass = props.getProperty("db.password");

    Class.forName("com.mysql.cj.jdbc.Driver");
%>
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Top Bidders Report</title>
</head>
<body>
  <h2>Top Bidders (by number of bids)</h2>
  <p>Logged in as <strong><%= username %></strong> (ADMIN)</p>

  <table border="1" cellpadding="4" cellspacing="0">
    <tr>
      <th>Rank</th>
      <th>Bidder</th>
      <th># Bids</th>
      <th># Auctions Participated</th>
      <th>Total Amount Bid</th>
    </tr>
<%
    String sql =
      "SELECT u.user_id, u.username, " +
      "COUNT(b.bid_id) AS num_bids, " +
      "COUNT(DISTINCT b.auction_id) AS num_auctions, " +
      "COALESCE(SUM(b.bid_amount), 0) AS total_amount " +
      "FROM bids b " +
      "JOIN users u ON b.bidder_id = u.user_id " +
      "GROUP BY u.user_id, u.username " +
      "ORDER BY num_bids DESC, total_amount DESC " +
      "LIMIT 20";

    try (Connection c = DriverManager.getConnection(url, dbUser, dbPass);
         PreparedStatement ps = c.prepareStatement(sql);
         ResultSet rs = ps.executeQuery()) {

        int rank = 1;
        boolean any = false;
        while (rs.next()) {
            any = true;
%>
    <tr>
      <td><%= rank++ %></td>
      <td><%= rs.getString("username") %></td>
      <td><%= rs.getInt("num_bids") %></td>
      <td><%= rs.getInt("num_auctions") %></td>
      <td><%= rs.getBigDecimal("total_amount") %></td>
    </tr>
<%
        }
        if (!any) {
%>
    <tr><td colspan="5"><em>No bids in the system yet.</em></td></tr>
<%
        }
    } catch (Exception e) {
%>
    <tr><td colspan="5">Error: <%= e.getMessage() %></td></tr>
<%
    }
%>
  </table>

  <p>
    <a href="adminDashboard.jsp">Back to Admin Dashboard</a> |
    <a href="home.jsp">Home</a>
  </p>
</body>
</html>
<%@ page contentType="text/html; charset=UTF-8" %>
<%
    String username = (String) session.getAttribute("username");
    String role     = (String) session.getAttribute("role");

    // Backwards-compat fallback: if you're still using "user", grab that
    if (username == null) {
        username = (String) session.getAttribute("user");
    }
    if (role == null) {
        role = "END_USER";  // default if not set yet
    }

    if (username == null) {
        response.sendRedirect("index.jsp?msg=Please+login");
        return;
    }
%>
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Home</title>
</head>
<body>
  <h2>Welcome, <%= username %>!</h2>
  <p>You are logged in as <strong><%= role %></strong>.</p>

  <%-- Role-based menus: extend these as you implement features --%>

  <% if ("ADMIN".equals(role)) { %>
    <h3>Admin menu</h3>
    <ul>
      <li><a href="adminDashboard.jsp">Admin dashboard</a></li>
      <li><a href="adminCreateRep.jsp">Create customer rep account</a></li>
      <li><a href="reports.jsp">View system reports</a></li>
      <li><a href="viewUserHistory.jsp">View history for specific user</a></li>
      <li><a href="maintenance.jsp">Maintenance</a></li>
    </ul>
  <% } else if ("REP".equals(role)) { %>
    <h3>Customer Representative menu</h3>
    <ul>
      <li><a href="repDashboard.jsp">Rep dashboard</a></li>
      <li><a href="repManageUsers.jsp">Manage users / questions</a></li>
      <li><a href="viewUserHistory.jsp">View other users' history</a></li>
      <li><a href="repManageBids.jsp">Manage bids (remove bids)</a></li>
      <li><a href="repManageAuctions.jsp">Manage auctions (close/remove)</a></li>
    </ul>
  
  <% } else { %>
    <h3>End-user menu</h3>
    <ul>
      <li><a href="newAuction.jsp">Create new auction</a></li>
      <li><a href="myAuctions.jsp">View my auctions</a></li>
      <li><a href="search.jsp">Search auctions</a></li>
      <li><a href="setAlert.jsp">Set alerts</a></li>
      <li><a href="userHistory.jsp">My bidding / selling history</a></li>
      <li><a href="allAuctions.jsp">Browse all open auctions</a></li>
      <li><a href="setAlert.jsp">Manage my alerts</a></li>
      <li><a href="alertMatches.jsp">Auctions matching my alerts</a></li>
      <li><a href="deleteAccount.jsp">Delete my account</a></li>
      <li><a href="browseQuestions.jsp">Browse questions & answers (FAQ)</a></li>
      <li><a href="notifications.jsp">My notifications</a></li>
    </ul>
  <% } %>
  

  <form method="post" action="logout.jsp">
    <button type="submit">Log Out</button>
  </form>
</body>
</html>
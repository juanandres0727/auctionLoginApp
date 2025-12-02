<%@ page import="java.sql.*,java.util.Properties,java.io.FileInputStream" %>
<%@ page contentType="text/html; charset=UTF-8" %>
<%
    //Requiere login
    Integer userIdObj = (Integer) session.getAttribute("user_id");
    String username   = (String) session.getAttribute("username");
    if (userIdObj == null || username == null) {
        response.sendRedirect("index.jsp?msg=Please+login");
        return;
    }
    int loggedUserId = userIdObj;

    request.setCharacterEncoding("UTF-8");

    //Input parameters
    String auctionStr = request.getParameter("auction_id");
    String bidStr     = request.getParameter("bid_amount");
    String autoStr    = request.getParameter("auto_max");

    int auctionId = -1;
    double bidAmount = 0.0;
    Double autoMax = null;

    String redirectMsg = null;

    //Parse inputs
    try {
        auctionId = Integer.parseInt(auctionStr);
        bidAmount = Double.parseDouble(bidStr);

        if (autoStr != null && !autoStr.trim().isEmpty()) {
            autoMax = Double.valueOf(autoStr);
            if (autoMax < bidAmount) {
                redirectMsg = "Auto-bid max must be >= your bid amount.";
            }
        }
    } catch (Exception e) {
        redirectMsg = "Invalid auction or bid amount.";
    }

    //Load db
    Properties props = new Properties();
    String propsPath = application.getRealPath("/WEB-INF/db.properties");
    try (FileInputStream fis = new FileInputStream(propsPath)) {
        props.load(fis);
    }

    String url    = props.getProperty("db.url");
    String dbUser = props.getProperty("db.user");
    String dbPass = props.getProperty("db.password");

    Class.forName("com.mysql.cj.jdbc.Driver");

    //If inputs OK then process bid
    if (redirectMsg == null) {

        try (Connection c = DriverManager.getConnection(url, dbUser, dbPass)) {
            c.setAutoCommit(false);

            //Lock the auction row
            String sql = "SELECT * FROM auctions WHERE auction_id=? FOR UPDATE";
            double currentPrice = 0, minIncrement = 0, reservePrice = 0;
            Timestamp endTime = null;
            String status = null;
            int sellerId = -1;
            String auctionTitle = "";

            try (PreparedStatement ps = c.prepareStatement(sql)) {
                ps.setInt(1, auctionId);
                try (ResultSet rs = ps.executeQuery()) {
                    if (!rs.next()) {
                        redirectMsg = "Auction not found.";
                    } else {
                        currentPrice = rs.getDouble("current_price");
                        minIncrement = rs.getDouble("min_increment");
                        reservePrice = rs.getDouble("reserve_price");
                        endTime      = rs.getTimestamp("end_time");
                        status       = rs.getString("status");
                        sellerId     = rs.getInt("seller_id");
                        auctionTitle = rs.getString("title");
                    }
                }
            }

            //Validate bid constraints
            if (redirectMsg == null) {
                java.util.Date now = new java.util.Date();
                if (!"OPEN".equals(status)) {
                    redirectMsg = "Auction is not open for bidding.";
                } else if (endTime == null || !endTime.after(now)) {
                    redirectMsg = "Auction has expired.";
                } else if (sellerId == loggedUserId) {
                    redirectMsg = "You cannot bid on your own auction.";
                } else {
                    double minAllowed = currentPrice + minIncrement;
                    if (bidAmount < minAllowed) {
                        redirectMsg = "Bid must be at least " + minAllowed;
                    }
                }
            }

            if (redirectMsg == null) {

                //Record this user's bid
                try (PreparedStatement ps = c.prepareStatement(
                     "INSERT INTO bids (auction_id, bidder_id, bid_amount) VALUES (?,?,?)")) {
                    ps.setInt(1, auctionId);
                    ps.setInt(2, loggedUserId);
                    ps.setDouble(3, bidAmount);
                    ps.executeUpdate();
                }

                // Update auctions.current_price
                try (PreparedStatement ps = c.prepareStatement(
                     "UPDATE auctions SET current_price=? WHERE auction_id=?")) {
                    ps.setDouble(1, bidAmount);
                    ps.setInt(2, auctionId);
                    ps.executeUpdate();
                }

                //Insert/update auto-bid max
                if (autoMax != null) {
                    try (PreparedStatement ps = c.prepareStatement(
                        "INSERT INTO auto_bids (auction_id, bidder_id, max_amount) " +
                        "VALUES (?,?,?) ON DUPLICATE KEY UPDATE max_amount=VALUES(max_amount)")) {
                        ps.setInt(1, auctionId);
                        ps.setInt(2, loggedUserId);
                        ps.setDouble(3, autoMax);
                        ps.executeUpdate();
                    }
                }

                //Notify all previous bidders
                try (PreparedStatement ps = c.prepareStatement(
                     "SELECT DISTINCT bidder_id FROM bids WHERE auction_id=? AND bidder_id<>?")) {
                    ps.setInt(1, auctionId);
                    ps.setInt(2, loggedUserId);

                    try (ResultSet rs = ps.executeQuery()) {
                        while (rs.next()) {
                            int otherId = rs.getInt("bidder_id");

                            try (PreparedStatement ins = c.prepareStatement(
                                 "INSERT INTO notifications (user_id, message) VALUES (?,?)")) {
                                String msg =
                                   "A higher bid was placed on auction #" + auctionId +
                                   " (\"" + auctionTitle + "\"). Visit the auction page.";
                                ins.setInt(1, otherId);
                                ins.setString(2, msg);
                                ins.executeUpdate();
                            }
                        }
                    }
                } catch (Exception ignore) {}

                //Auto-bidding loop with alerts
                boolean autoDone = false;

                while (!autoDone) {
                    autoDone = true;

                    // Refresh current price
                    double curPrice = 0, minInc = 0;

                    try (PreparedStatement ps = c.prepareStatement(
                         "SELECT current_price, min_increment FROM auctions WHERE auction_id=?")) {
                        ps.setInt(1, auctionId);
                        try (ResultSet rs = ps.executeQuery()) {
                            rs.next();
                            curPrice = rs.getDouble("current_price");
                            minInc   = rs.getDouble("min_increment");
                        }
                    }

                    //Find best auto-bidder except current top bidder
                    int autoBidderId = -1;
                    double maxAmt = 0.0;

                    try (PreparedStatement ps = c.prepareStatement(
                        "SELECT bidder_id, max_amount FROM auto_bids " +
                        "WHERE auction_id=? AND max_amount>=? " +
                        "ORDER BY max_amount DESC LIMIT 1")) {

                        ps.setInt(1, auctionId);
                        ps.setDouble(2, curPrice + minInc);

                        try (ResultSet rs = ps.executeQuery()) {
                            if (rs.next()) {
                                autoBidderId = rs.getInt("bidder_id");
                                maxAmt       = rs.getDouble("max_amount");
                            }
                        }
                    }

                    if (autoBidderId != -1) {

                        double nextBid = curPrice + minInc;
                        if (nextBid > maxAmt) nextBid = maxAmt;

                        //Place auto-bid
                        try (PreparedStatement ps = c.prepareStatement(
                             "INSERT INTO bids (auction_id, bidder_id, bid_amount) VALUES (?,?,?)")) {
                            ps.setInt(1, auctionId);
                            ps.setInt(2, autoBidderId);
                            ps.setDouble(3, nextBid);
                            ps.executeUpdate();
                        }

                        // Update auction price
                        try (PreparedStatement ps = c.prepareStatement(
                             "UPDATE auctions SET current_price=? WHERE auction_id=?")) {
                            ps.setDouble(1, nextBid);
                            ps.setInt(2, auctionId);
                            ps.executeUpdate();
                        }

                        //auto_max exceeded
                        if (autoBidderId != loggedUserId) {
                            try (PreparedStatement ins = c.prepareStatement(
                                "INSERT INTO notifications (user_id, message) VALUES (?,?)")) {
                                String msg =
                                   "Your auto-bid limit on auction #" + auctionId +
                                   " (\"" + auctionTitle + "\") has been exceeded.";
                                ins.setInt(1, autoBidderId);
                                ins.setString(2, msg);
                                ins.executeUpdate();
                            } catch (Exception ignore) {}
                        }

                        autoDone = false; //continue loop
                    }
                } //end auto loop

                c.commit();
                redirectMsg = "Bid placed successfully.";
            } else {
                c.rollback();
            }
        } catch (Exception e) {
            redirectMsg = "Error: " + e.getMessage();
        }
    }

    //redirect back
    response.sendRedirect(
      "viewAuction.jsp?auction_id=" + auctionId +
      "&bidMsg=" + java.net.URLEncoder.encode(redirectMsg, "UTF-8")
    );
%>
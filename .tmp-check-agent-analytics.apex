LibraryAgentAnalyticsAction.Response r = LibraryAgentAnalyticsAction.execute(new List<LibraryAgentAnalyticsAction.Request>{new LibraryAgentAnalyticsAction.Request()})[0];
System.debug(LoggingLevel.ERROR, 'CHECK available=' + r.available + ' message=' + r.message + ' totalLoans=' + r.totalLoans + ' overdueLoans=' + r.overdueLoans + ' lastUpdated=' + r.lastUpdated);

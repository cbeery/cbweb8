# 1

Rails 8 app, see the repo and claude.md for details.

New feature: /listening controller for displaying more of the data from TopScrobble like the home card, and ScrobblePlay and ScrobbleCount.

Also: create a reusable pattern for this page, with conventions to be followed by other public pages.

/listening controller specifics:

* index view has multiple css bar charts, exact same pattern and style as Listening card on home page
* charts include
	* Top Artists, last week
	* Top Artists, last month
	* Top Artists, last year
	* Top Artists, all-time (since 2008)
	* Top Albums, last month
	* Top Albums, last year
	* Top Tracks, last month
	* Top Tracks, last year
* Artists display artist image (like home card), album and track display album image (rounded square)
* CSS charts in 2-col at size md or larger, 1-col at sm or smaller
* See this page for reference: https://curtbeery.com/tunes

Public index page pattern:

* General layout
	* Top: heading, maybe subheading and spot for text
	* Main section: left side, maybe 9 or 10 out of 12 columns. Content itself could be anything
	* Right-side subsection, consists of side subsections
		1. Maybe an h2 here, maybe some extemporaneous p-tag text
		2. A Nav section, linking to other actions/views within the controller
		3. A below the nav "more details" section like lists, css bar graphs, etc.
	* On mobile size:
		* Side Sub-section 1 goes above main content
		* Side Sub-section 2 (nav) goes above main content, but is collapsible, and initial state is collapsed
		* Side Sub-section 3 goes *below* the main content


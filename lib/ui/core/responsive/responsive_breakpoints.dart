/// Breakpoints based on available window width (not device type).
const double largeScreenMinWidth = 600;

/// Two-column layouts for planning cards and similar content.
const double expandedContentMinWidth = 900;

/// Max width for primary scrollable content on large displays.
const double contentMaxWidth = 800;

/// Max width for forms and modals.
const double formMaxWidth = 640;

/// Max width for the stacked friend photo card.
const double feedCardMaxWidth = 480;

const double navigationRailWidth = 88;

bool isLargeScreen(double maxWidth) => maxWidth > largeScreenMinWidth;

bool isExpandedContent(double maxWidth) => maxWidth > expandedContentMinWidth;

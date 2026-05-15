class ThemeFontSize {
  double get body => 16;
  double get small => 0.75 * body;
  double get heading => 2 * body;
  double get subheading => 1.5 * body;
  double get subsubheading => 1.25 * body;
}

class ThemeFontFamily {
  // Font families
  String get arial => 'Arial';
  String get roboto => 'RobotoSlab';

  // Aliases
  String get body => arial;
  String get heading => roboto;
  String get subheading => arial;
  String get subsubheading => arial;
}

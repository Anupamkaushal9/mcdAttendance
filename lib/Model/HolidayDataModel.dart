class Holiday {
  final String holidayDate;
  final String holidayOccasion;
  final String masterDescriptionText;

  // Constructor
  Holiday({
    required this.holidayDate,
    required this.holidayOccasion,
    required this.masterDescriptionText,
  });

  // Factory method to create a Holiday from a JSON object (for easy parsing from JSON data)
  factory Holiday.fromJson(Map<String, dynamic> json) {
    return Holiday(
      holidayDate: json['holiday_date'] as String,
      holidayOccasion: json['holiday_occasion'] as String,
      masterDescriptionText: json['master_description_text'] as String,
    );
  }

  // Method to convert the Holiday object to JSON (if you want to send or store the data)
  Map<String, dynamic> toJson() {
    return {
      'holiday_date': holidayDate,
      'holiday_occasion': holidayOccasion,
      'master_description_text': masterDescriptionText,
    };
  }
}

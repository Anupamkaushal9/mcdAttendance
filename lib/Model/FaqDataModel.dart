class FAQDataModel {
  final String faqQues; // Question
  final String faqAns; // Answer

  // Constructor
  FAQDataModel({required this.faqQues, required this.faqAns});

  // Factory method to create an FAQ instance from a Map
  factory FAQDataModel.fromJson(Map<String, dynamic> json) {
    return FAQDataModel(
      faqQues: json['faq_ques'], // Accessing the 'faq_ques' field from the JSON
      faqAns: json['faq_ans'],  // Accessing the 'faq_ans' field from the JSON
    );
  }

  // Method to convert the FAQ instance to a JSON map (for when sending data back)
  Map<String, dynamic> toJson() {
    return {
      'faq_ques': faqQues,
      'faq_ans': faqAns,
    };
  }
}

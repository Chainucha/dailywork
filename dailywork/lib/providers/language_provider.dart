import 'package:flutter_riverpod/flutter_riverpod.dart';

// Toggles between 'en' and 'kn'
final languageProvider = StateProvider<String>((ref) => 'en');

// English strings
const Map<String, String> _enStrings = {
  'home': 'Home',
  'jobs': 'Jobs',
  'profile': 'Profile',
  'apply': 'Apply',
  'urgent': 'Urgent',
  'open': 'Open',
  'assigned': 'Assigned',
  'in_progress': 'In Progress',
  'completed': 'Completed',
  'cancelled': 'Cancelled',
  'worker': "I'm a Worker",
  'employer': "I'm an Employer",
  'search_grow': 'Search & Grow Your Career',
  'recommended': 'Recommended Jobs',
  'my_jobs': 'My Posted Jobs',
  'per_day': '/day',
  'away': 'away',
  'workers_needed': 'Workers Needed',
  'start_date': 'Start Date',
  'wage': 'Wage',
  'description': 'Description',
  'applicants': 'applicants',
  'filter': 'Filter',
  'apply_filters': 'Apply Filters',
  'status': 'Status',
  'wage_range': 'Wage Range',
  'core_skills': 'Core Skills',
  'recent_reviews': 'Recent Reviews',
  'experience': 'Experience',
  'jobs_completed': 'Jobs Done',
  'reliability': 'Reliability',
  'applied': 'Applied!',
  'apply_success': 'Application submitted successfully',
  'post_job': 'Post Job',
  'coming_soon': 'Coming soon',
  'years': 'Yrs',
  'km_away': '~5 km away',
};

// Kannada strings
const Map<String, String> _knStrings = {
  'home': 'ಮನೆ',
  'jobs': 'ಕೆಲಸಗಳು',
  'profile': 'ಪ್ರೊಫೈಲ್',
  'apply': 'ಅರ್ಜಿ ಹಾಕಿ',
  'urgent': 'ತುರ್ತು',
  'open': 'ತೆರೆದಿದೆ',
  'assigned': 'ನಿಯೋಜಿಸಲಾಗಿದೆ',
  'in_progress': 'ನಡೆಯುತ್ತಿದೆ',
  'completed': 'ಮುಗಿದಿದೆ',
  'cancelled': 'ರದ್ದಾಗಿದೆ',
  'worker': 'ನಾನು ಕಾರ್ಮಿಕ',
  'employer': 'ನಾನು ಉದ್ಯೋಗದಾತ',
  'search_grow': 'ಕೆಲಸ ಹುಡುಕಿ ಬೆಳೆಯಿರಿ',
  'recommended': 'ಶಿಫಾರಸು ಮಾಡಿದ ಕೆಲಸಗಳು',
  'my_jobs': 'ನನ್ನ ಪೋಸ್ಟ್ ಮಾಡಿದ ಕೆಲಸಗಳು',
  'per_day': '/ದಿನ',
  'away': 'ದೂರ',
  'workers_needed': 'ಬೇಕಾದ ಕಾರ್ಮಿಕರು',
  'start_date': 'ಪ್ರಾರಂಭ ದಿನಾಂಕ',
  'wage': 'ವೇತನ',
  'description': 'ವಿವರಣೆ',
  'applicants': 'ಅರ್ಜಿದಾರರು',
  'filter': 'ಫಿಲ್ಟರ್',
  'apply_filters': 'ಫಿಲ್ಟರ್ ಅನ್ವಯಿಸಿ',
  'status': 'ಸ್ಥಿತಿ',
  'wage_range': 'ವೇತನ ವ್ಯಾಪ್ತಿ',
  'core_skills': 'ಮೂಲ ಕೌಶಲ್ಯಗಳು',
  'recent_reviews': 'ಇತ್ತೀಚಿನ ವಿಮರ್ಶೆಗಳು',
  'experience': 'ಅನುಭವ',
  'jobs_completed': 'ಮಾಡಿದ ಕೆಲಸಗಳು',
  'reliability': 'ವಿಶ್ವಾಸಾರ್ಹತೆ',
  'applied': 'ಅರ್ಜಿ ಸಲ್ಲಿಸಲಾಗಿದೆ!',
  'apply_success': 'ಅರ್ಜಿ ಯಶಸ್ವಿಯಾಗಿ ಸಲ್ಲಿಸಲಾಗಿದೆ',
  'post_job': 'ಕೆಲಸ ಪೋಸ್ಟ್ ಮಾಡಿ',
  'coming_soon': 'ಶೀಘ್ರದಲ್ಲಿ ಬರಲಿದೆ',
  'years': 'ವರ್ಷ',
  'km_away': '~5 ಕಿ.ಮೀ ದೂರ',
};

// Provider that returns current strings map
final stringsProvider = Provider<Map<String, String>>((ref) {
  final lang = ref.watch(languageProvider);
  return lang == 'kn' ? _knStrings : _enStrings;
});

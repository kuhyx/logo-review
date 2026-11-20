/// Bootstrap only: the real network, keystore and phone services.
library;

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:logo_review/api.dart';
import 'package:logo_review/controller.dart';
import 'package:logo_review/errors.dart';
import 'package:logo_review/store.dart';
import 'package:logo_review/ui/app.dart';
import 'package:logo_review/ui/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ReviewApi(http.Client());
  final errors = ErrorReporter(api.report)..install();
  runApp(
    LogoReviewApp(
      controller: ReviewController(
        api,
        const SecureTokenStore(),
        onError: errors.report,
      ),
      services: const Services.phone(),
      errors: errors,
    ),
  );
}

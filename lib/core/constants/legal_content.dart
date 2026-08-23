/// Static in-app documents: Privacy Policy, Terms, About, Help.
///
/// **These are drafts written to match what the app actually does — they are
/// not legal advice and have not been reviewed by a lawyer.** Have counsel
/// review both the Privacy Policy and the Terms before publishing to the Play
/// Store.
///
/// They are deliberately accurate about current behaviour rather than
/// aspirational: the app really does collect precise location, really does
/// send descriptions and photos to a third-party AI, and the "Verified" badge
/// really is a manual administrator decision rather than an identity check.
library;

class StaticSection {
  final String? heading;
  final String body;
  const StaticSection({this.heading, required this.body});
}

class StaticDocument {
  final String title;
  final String? lastUpdated;
  final List<StaticSection> sections;

  const StaticDocument({
    required this.title,
    required this.sections,
    this.lastUpdated,
  });
}

const _companyName = 'Fixwaala';
const _contactEmail = 'support@fixwaala.com';

class LegalContent {
  LegalContent._();

  static const privacyPolicy = StaticDocument(
    title: 'Privacy Policy',
    lastUpdated: 'August 2026',
    sections: [
      StaticSection(
        body:
            'This policy explains what Fixwaala collects, why, and who can see '
            'it. It describes the app as it currently behaves.',
      ),
      StaticSection(
        heading: 'What we collect',
        body:
            '• Account details: your name, email address, and phone number.\n'
            '• Location: your approximate location when you raise a request, '
            'and your precise address only after you confirm a provider. '
            'Providers share live location while they are online.\n'
            '• Request content: your description of the problem and any '
            'photos you attach.\n'
            '• Service history: jobs, payments, and ratings.\n'
            '• Device identifiers used to deliver notifications.',
      ),
      StaticSection(
        heading: 'Who can see your address',
        body:
            'Your exact address and full name are not shared with providers '
            'while we are searching. Providers nearby see only your first '
            'name, an approximate location, and the problem description. Your '
            'precise address is revealed to a single provider at the moment '
            'you confirm them, and to nobody else.',
      ),
      StaticSection(
        heading: 'Third parties',
        body:
            'We use Google Firebase for accounts, data storage, and '
            'notifications; Google Gemini to help categorise your request '
            '(your description and the number of photos are sent, via our own '
            'server); and Cloudinary to host photos you upload. We do not '
            'sell your data.',
      ),
      StaticSection(
        heading: 'Retention and deletion',
        body:
            'Service records are retained while your account is active. To '
            'request deletion of your account and associated data, contact '
            '$_contactEmail.',
      ),
      StaticSection(
        heading: 'Contact',
        body: 'Questions about this policy: $_contactEmail ($_companyName).',
      ),
    ],
  );

  static const termsOfService = StaticDocument(
    title: 'Terms of Service',
    lastUpdated: 'August 2026',
    sections: [
      StaticSection(
        body:
            'By using Fixwaala you agree to these terms. Please read the '
            'section on our role carefully.',
      ),
      StaticSection(
        heading: 'What Fixwaala is',
        body:
            'Fixwaala is a marketplace that connects customers with '
            'independent service providers. We are not the provider of the '
            'repair work. Providers are not our employees, and the contract '
            'for any work is between you and them.',
      ),
      StaticSection(
        heading: 'The "Verified" badge',
        body:
            'A "Verified" badge means a Fixwaala administrator has manually '
            'reviewed that provider. It is not a government identity check, a '
            'background check, or a licence verification, and it is not a '
            'guarantee of the quality or safety of their work. Use your own '
            'judgement before admitting anyone to your home.',
      ),
      StaticSection(
        heading: 'Payments',
        body:
            'Payments in this version of the app are simulated for '
            'demonstration and no money changes hands. Settle payment with '
            'your provider directly and keep your own record of it.',
      ),
      StaticSection(
        heading: 'Cancellations',
        body:
            'You may cancel a request at any time before a provider is '
            'assigned. Once a provider is assigned and travelling, please '
            'contact them directly.',
      ),
      StaticSection(
        heading: 'Acceptable use',
        body:
            'Do not submit false requests, abuse providers or customers, or '
            'file knowingly false reports. Accounts may be restricted or '
            'suspended for doing so.',
      ),
      StaticSection(
        heading: 'Emergencies',
        body:
            'Fixwaala is not an emergency service. The in-app SOS flags a job '
            'for our safety team and is not monitored around the clock. In an '
            'emergency call 112 (or 100 for police, 108 for ambulance).',
      ),
      StaticSection(
        heading: 'Liability',
        body:
            'To the extent permitted by law, $_companyName is not liable for '
            'the acts or omissions of independent providers or customers '
            'introduced through the app.',
      ),
    ],
  );

  static const about = StaticDocument(
    title: 'About Fixwaala',
    sections: [
      StaticSection(
        body:
            'Fixwaala connects you with nearby plumbers, electricians, and '
            'carpenters — and lets you review who is coming before they are '
            'assigned.',
      ),
      StaticSection(
        heading: 'How matching works',
        body:
            'Your request is broadcast to nearby providers with the right '
            'skills, starting within 5 km and widening if nobody responds. '
            'Providers who accept appear as candidates; you review their '
            'rating and history and confirm one. Only then is your exact '
            'address shared.',
      ),
      StaticSection(heading: 'Version', body: 'Fixwaala 1.0.0 (build 1)'),
    ],
  );

  static const help = StaticDocument(
    title: 'Help & Support',
    sections: [
      StaticSection(
        heading: 'No providers are responding',
        body:
            'The search widens automatically from 5 km to 15 km over a few '
            'minutes. If nobody accepts, the request stops and you can raise '
            'a new one — try adding more detail or photos.',
      ),
      StaticSection(
        heading: 'I am a provider and see no jobs',
        body:
            'Check that you are online, that you have selected at least one '
            'skill under Skills & availability, and that location permission '
            'is granted. The home screen will tell you which of these is '
            'missing.',
      ),
      StaticSection(
        heading: 'I need to change my details',
        body:
            'Open Profile and tap Edit to update your name or phone number. '
            'Providers can change skills and availability from Profile → '
            'Skills & availability.',
      ),
      StaticSection(
        heading: 'Something went wrong on a job',
        body:
            'Use "Report an Issue" from your profile. If you feel unsafe '
            'during a job, use SOS — and in an immediate emergency call 112.',
      ),
      StaticSection(
        heading: 'Still stuck?',
        body: 'Email $_contactEmail and include your registered email address.',
      ),
    ],
  );
}

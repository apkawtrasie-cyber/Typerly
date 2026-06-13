# Typerly - Modern Social Sports Prediction App

A modern, community-driven sports prediction application built with Flutter and Supabase. Compete with friends in private leagues, predict match results, and earn virtual currency (Gemingi).

## Features

### Core Features
- **User Authentication**: Email/password registration with email verification
- **Match Predictions**: Predict scores for upcoming matches
- **Private Leagues**: Create and join private leagues with friends
- **Real-time Updates**: Live match scores and league standings via Supabase Realtime
- **Virtual Currency**: Gemingi system for league entry fees and rewards
- **Multi-sport Support**: Football, Basketball, Tennis, F1, and custom sports

### Premium Features
- **Unlimited Leagues**: Create as many private leagues as you want
- **Custom Matches**: Add your own local matches (e.g., friendly games, office bets)
- **Ad-Free Experience**: No advertisements
- **Advanced Analytics**: Detailed statistics and trends

### Free Tier Limitations
- Maximum 1 private league
- No custom matches
- Ad-supported experience
- Official API matches only

## Tech Stack

- **Frontend**: Flutter 3.0+
- **State Management**: BLoC (flutter_bloc)
- **Backend**: Supabase (PostgreSQL, Auth, Realtime)
- **External API**: API-Football for official match data
- **Ads**: Google AdMob (for free users)
- **Charts**: FL Chart for data visualization

## Project Structure

```
lib/
├── core/
│   ├── config/
│   │   ├── env_config.dart       # Environment variables
│   │   ├── supabase_config.dart  # Supabase client setup
│   │   └── app_theme.dart        # App theme and colors
│   └── theme/
├── models/
│   ├── profile.dart              # User profile model
│   ├── league.dart               # League model
│   ├── league_member.dart        # League membership model
│   ├── match.dart                # Match model
│   └── prediction.dart           # Prediction model
├── features/
│   └── auth/
│       ├── auth_bloc.dart        # Authentication BLoC
│       ├── auth_event.dart
│       ├── auth_state.dart
│       └── auth_repository.dart  # Auth data layer
├── services/
│   └── premium_service.dart      # Premium/Free tier logic
├── widgets/
│   ├── buttons/
│   │   ├── primary_button.dart
│   │   └── secondary_button.dart
│   ├── cards/
│   │   ├── match_card.dart
│   │   ├── league_card.dart
│   │   └── stat_card.dart
│   └── inputs/
│       └── custom_text_field.dart
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── home/
│   │   └── home_screen.dart
│   ├── groups/
│   │   ├── groups_screen.dart
│   │   ├── create_group_screen.dart
│   │   └── custom_group_screen.dart
│   ├── profile/
│   │   └── profile_screen.dart
│   ├── match/
│   │   └── match_detail_screen.dart
│   └── main_screen.dart          # Main navigation
└── main.dart                     # App entry point
```

## Database Schema

The application uses the following Supabase tables:

### profiles
User profiles linked to Supabase Auth
- `id` (UUID, primary key, references auth.users)
- `username` (TEXT, unique)
- `avatar_url` (TEXT, nullable)
- `is_premium` (BOOLEAN, default: false)
- `premium_until` (TIMESTAMP, nullable)
- `created_at` (TIMESTAMP)

### leagues
Private leagues/groups
- `id` (UUID, primary key)
- `name` (TEXT)
- `invite_code` (TEXT, unique)
- `admin_id` (UUID, references profiles)
- `entry_fee_gemings` (INTEGER, default: 0)
- `created_at` (TIMESTAMP)

### league_members
League membership with gemings balance
- `id` (UUID, primary key)
- `league_id` (UUID, references leagues)
- `user_id` (UUID, references profiles)
- `gemings_balance` (INTEGER, default: 0)
- `is_approved_by_admin` (BOOLEAN, default: false)
- `joined_at` (TIMESTAMP)

### matches
Match data (official from API or custom)
- `id` (UUID, primary key)
- `api_fixture_id` (INTEGER, nullable)
- `sport_type` (TEXT, default: 'football')
- `home_team_name` (TEXT)
- `away_team_name` (TEXT)
- `home_team_logo_url` (TEXT, nullable)
- `away_team_logo_url` (TEXT, nullable)
- `match_time` (TIMESTAMP)
- `status` (TEXT: 'NS', 'LIVE', 'FT')
- `home_score` (INTEGER, nullable)
- `away_score` (INTEGER, nullable)
- `is_custom` (BOOLEAN, default: false)
- `creator_id` (UUID, references profiles, nullable)
- `league_id` (UUID, references leagues, nullable)
- `created_at` (TIMESTAMP)

### predictions
User predictions for matches
- `id` (UUID, primary key)
- `user_id` (UUID, references profiles)
- `match_id` (UUID, references matches)
- `league_id` (UUID, references leagues)
- `predicted_home_score` (INTEGER)
- `predicted_away_score` (INTEGER)
- `points_earned` (INTEGER, default: 0)
- `is_calculated` (BOOLEAN, default: false)
- `updated_at` (TIMESTAMP)

## Setup Instructions

### Prerequisites
- Flutter SDK 3.0 or higher
- Dart SDK 3.0 or higher
- A Supabase project
- API-Football API key (optional, for official match data)
- Google AdMob account (optional, for ads)

### 1. Clone the Repository
```bash
git clone <repository-url>
cd Typerly
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Configure Environment Variables

Create a `.env` file in the project root:

```env
# Supabase Configuration
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key

# API-Football Configuration
API_FOOTBALL_KEY=your_api_football_key
API_FOOTBALL_BASE_URL=https://v3.football.api-sports.io

# AdMob Configuration
ADMOB_BANNER_ID_ANDROID=ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx
ADMOB_BANNER_ID_IOS=ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx
ADMOB_INTERSTITIAL_ID_ANDROID=ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx
ADMOB_INTERSTITIAL_ID_IOS=ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx

# App Configuration
APP_NAME=Typerly
APP_ENV=development
```

### 4. Set Up Supabase Database

Run the provided SQL schema in your Supabase SQL Editor:

```sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create tables (see Database Schema section above)
-- Run the complete SQL schema provided in the project documentation
```

### 5. Generate JSON Serialization Code

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 6. Run the App

```bash
flutter run
```

## Design System

### Colors
- **Background**: `#0A0A0A` (Deep black)
- **Surface**: `#141414` (Dark gray)
- **Card**: `#1A1A1A` (Lighter gray)
- **Primary**: `#CCFF00` (Neon green/lime)
- **Secondary**: `#FFD700` (Gold/yellow)
- **Error**: `#FF4444` (Red)
- **Success**: `#00CC66` (Green)
- **Text Primary**: `#FFFFFF` (White)
- **Text Secondary**: `#B0B0B0` (Light gray)
- **Text Tertiary**: `#707070` (Medium gray)
- **Divider**: `#2A2A2A` (Dark gray)
- **Live**: `#FF0000` (Red)

### Typography
- **Font Family**: Inter
- **Weights**: Regular (400), Medium (500), SemiBold (600), Bold (700)

### Components
- **Primary Button**: Neon green background, black text
- **Secondary Button**: Neon green border, neon green text
- **Cards**: Rounded corners (16px), dark background
- **Inputs**: Dark background, neon green focus border

## Premium/Free Tier Logic

The `PremiumService` class handles all premium/free tier restrictions:

### League Creation
- Free users: Maximum 1 league
- Premium users: Unlimited leagues

### Custom Matches
- Free users: Not available
- Premium users: Available

### Advertisements
- Free users: Ads shown
- Premium users: No ads

Example usage:
```dart
import '../services/premium_service.dart';

// Check if user can create a league
if (PremiumService.canCreateLeague(profile, currentLeagueCount)) {
  // Allow creation
} else {
  // Show upgrade dialog
}

// Check if user can create custom matches
if (PremiumService.canCreateCustomMatches(profile)) {
  // Allow custom matches
} else {
  // Show premium required dialog
}
```

## API Integration

### Supabase
- Authentication: Email/password with email verification
- Database: PostgreSQL with Realtime subscriptions
- Storage: For user avatars (optional)

### API-Football
- Used for official match data
- Automatic score updates
- Team logos and metadata

## Development

### Code Generation
Run this after modifying models:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Testing
```bash
flutter test
```

### Build for Production

**Android:**
```bash
flutter build apk --release
```

**iOS:**
```bash
flutter build ios --release
```

## Contributing

1. Follow the existing code structure
2. Use BLoC for state management
3. Write clean, modular code
4. Add comments for complex logic
5. Test thoroughly before committing

## License

Proprietary - All rights reserved

## Support

For issues and questions, contact the development team.

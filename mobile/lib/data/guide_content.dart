import 'package:flutter/material.dart';

enum GuideDifficulty {
  beginner,
  intermediate,
  advanced,
}

extension GuideDifficultyExtension on GuideDifficulty {
  String get label {
    switch (this) {
      case GuideDifficulty.beginner:
        return 'Beginner';
      case GuideDifficulty.intermediate:
        return 'Intermediate';
      case GuideDifficulty.advanced:
        return 'Advanced';
    }
  }

  Color get color {
    switch (this) {
      case GuideDifficulty.beginner:
        return const Color(0xFF00E676); // Green
      case GuideDifficulty.intermediate:
        return const Color(0xFF00E5FF); // Cyan
      case GuideDifficulty.advanced:
        return const Color(0xFFFF6D00); // Orange
    }
  }
}

class GuideArticle {
  final String id;
  final String categoryId;
  final String title;
  final String summary;
  final GuideDifficulty difficulty;
  final int readTimeMinutes;
  final List<String> tags;
  final String markdownContent;
  final List<String> keyTakeaways;

  const GuideArticle({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.summary,
    required this.difficulty,
    required this.readTimeMinutes,
    required this.tags,
    required this.markdownContent,
    this.keyTakeaways = const [],
  });
}

class GuideCategory {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final List<GuideArticle> articles;

  const GuideCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.articles,
  });
}

class GuideTip {
  final String id;
  final String title;
  final String content;
  final String category;
  final String? articleId;
  final GuideDifficulty difficulty;
  final IconData icon;

  const GuideTip({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    this.articleId,
    required this.difficulty,
    this.icon = Icons.lightbulb_outline,
  });
}

class GuideData {
  static const List<GuideTip> dailyTips = [
    GuideTip(
      id: 'tip_shielding',
      title: 'Shielding is Automatic',
      content: 'In v4.0+, manual shielding was replaced with context-aware auto-shielding. Keep body position between defender and ball by easing off sprint.',
      category: 'Mechanics',
      articleId: 'touch_controls',
      difficulty: GuideDifficulty.beginner,
      icon: Icons.shield_outlined,
    ),
    GuideTip(
      id: 'tip_finesse_dribble',
      title: 'Finesse Dribble for 1v1s',
      content: 'Use Finesse Dribble to face the goal with micro-touches. It gives instant acceleration bursts when escaping congested spaces.',
      category: 'Dribbling',
      articleId: 'dribbling_guide',
      difficulty: GuideDifficulty.intermediate,
      icon: Icons.directions_run,
    ),
    GuideTip(
      id: 'tip_match_up',
      title: 'Master Match-up Defending',
      content: 'Hold Match-up to jockey and block passing lanes automatically. Never sprint-tackle wildly in central midfield.',
      category: 'Defending',
      articleId: 'defending_guide',
      difficulty: GuideDifficulty.beginner,
      icon: Icons.security,
    ),
    GuideTip(
      id: 'tip_weak_foot',
      title: 'Check Weak Foot Usage',
      content: 'Wingers and AMFs need at least 2★-3★ weak foot usage to avoid awkward turn delays when crossing or passing.',
      category: 'Attributes',
      articleId: 'player_attributes',
      difficulty: GuideDifficulty.intermediate,
      icon: Icons.star_border,
    ),
    GuideTip(
      id: 'tip_overload',
      title: 'Overload Playstyle (Season 2027)',
      content: 'The Overload tactic stacks players toward the ball side. Combine with fast one-touch passes to break low defensive blocks.',
      category: 'Tactics',
      articleId: 'fluid_formations',
      difficulty: GuideDifficulty.advanced,
      icon: Icons.groups_2_outlined,
    ),
    GuideTip(
      id: 'tip_double_touch',
      title: 'Double Touch Timing',
      content: 'Execute Double Touch just before the defender commits to a challenge. Spamming it early allows AI defenders to intercept.',
      category: 'Skills',
      articleId: 'skill_moves_breakdown',
      difficulty: GuideDifficulty.intermediate,
      icon: Icons.sports_soccer,
    ),
  ];

  static const List<GuideCategory> categories = [
    // 1. Controls & Basics
    GuideCategory(
      id: 'getting_started',
      title: 'Getting Started & Controls',
      subtitle: 'Touch controls, Smart Assist, and essential settings',
      icon: Icons.touch_app,
      accentColor: Color(0xFF00E5FF),
      articles: [
        GuideArticle(
          id: 'touch_controls',
          categoryId: 'getting_started',
          title: 'Mobile Touch Controls & Layout',
          summary: 'Master the on-screen buttons, flick commands, and swipe actions on iOS and Android.',
          difficulty: GuideDifficulty.beginner,
          readTimeMinutes: 4,
          tags: ['Controls', 'Touch', 'Smart Assist', 'Settings'],
          keyTakeaways: [
            'Classic uses dedicated on-screen buttons; Touch & Flick offers gesture controls.',
            'Smart Assist automates shot power and dribble paths for beginners.',
            'Shielding is now automatic in modern eFootball Mobile.',
          ],
          markdownContent: '''
# Mobile Touch Controls & Layout

eFootball Mobile is built from the ground up for touchscreen precision. 

## Control Types: Classic vs. Touch & Flick

1. **Classic Controls (Recommended for most players):**
   - **Virtual Directional Stick (Left side):** Directs player movement, dribbling angles, and pass targeting.
   - **Action Buttons (Right side):**
     - **Pass:** Tap for short ground pass; flick up for lofted pass; flick right for through ball.
     - **Through Ball:** Slide/flick towards target direction.
     - **Shot:** Tap and hold to charge power; flick to curl (Finesse Shot).
     - **Dash (Sprint):** Hold to sprint. Combine with direction flicks for **Sharp Touch**.

2. **Smart Assist Feature:**
   - Designed to assist beginners by auto-calculating optimal shot power, curling angles, and dribbling orientation.
   - *Pro Tip:* Turn off Smart Assist in Settings once you are comfortable to regain 100% manual control over pass weight and shot placement.

## Modern Shielding Mechanics (v4.0+)
- The dedicated manual shield button was removed.
- Players automatically shield the ball using their physical frame when an opponent approaches from behind or the flank.
- **How to trigger effective shielding:** Release the Dash button and use gentle directional joystick movement to position your player's back toward the challenger. High **Physical Contact** and **Ball Control** stats enhance this effect significantly.

## Recommended In-Game Settings
- **Camera:** Dynamic Wide or Stadium (gives maximum tactical view of runs).
- **Player Switching:** Assisted or Semi-Auto based on preference.
- **Directional Stick:** Fixed or Medium Off-center for consistent thumb placement.
''',
        ),
        GuideArticle(
          id: 'ui_settings_optimization',
          categoryId: 'getting_started',
          title: 'UI Navigation & Pro Settings',
          summary: 'Configure graphic fidelity, 60fps refresh rate, radar settings, and audio cues for competitive advantage.',
          difficulty: GuideDifficulty.beginner,
          readTimeMinutes: 3,
          tags: ['Settings', 'FPS', 'Camera', 'Radar'],
          keyTakeaways: [
            'Always enable 60 FPS in graphics settings for responsive input registration.',
            'Keep the bottom radar ON to spot open wingers on counter-attacks.',
          ],
          markdownContent: '''
# UI Navigation & Pro Settings

Proper game settings give you an immediate competitive edge in tournament and division matches.

## Performance & Display Settings
- **Frame Rate:** Set to **60 FPS** (or 90/120 FPS if supported by your device). 30 FPS introduces input lag that disrupts dribble timing.
- **Graphics Quality:** Set to Standard or High. If experiencing thermal throttling during extended sessions, choose Standard.

## Match Screen & HUD
- **Radar Display:** Set to **Bottom** with distinct team colors. The radar lets you spot overlapping fullback runs before they appear on your main camera.
- **Stamina Gauge:** Always keep visible to time your second-half substitutions.
- **Player Name Display:** Show Player Name over cursor to quickly identify weak-foot orientation.
''',
        ),
      ],
    ),

    // 2. Gameplay Mechanics
    GuideCategory(
      id: 'mechanics',
      title: 'Core Gameplay Mechanics',
      subtitle: 'Passing, shooting, dribbling, and match-up defending',
      icon: Icons.sports_soccer,
      accentColor: Color(0xFFFF6D00),
      articles: [
        GuideArticle(
          id: 'passing_masterclass',
          categoryId: 'mechanics',
          title: 'Passing Masterclass: Ground, Lofted & Stunning',
          summary: 'Learn pass weight, one-touch combos, stunning passes, and through-ball trajectory control.',
          difficulty: GuideDifficulty.intermediate,
          readTimeMinutes: 5,
          tags: ['Passing', 'Stunning Pass', 'Through Ball', 'Vision'],
          keyTakeaways: [
            'Stunning Pass (flick pass button) delivers high-velocity pinpoint balls with a wind-up animation.',
            'Use Low Passes into the feet of target men to trigger quick lay-offs.',
            'Through passes require open space; never force them directly through a set defensive line.',
          ],
          markdownContent: '''
# Passing Masterclass

Passing is the lifeblood of eFootball. Success depends on player balance, body orientation, and passing weight.

## Types of Passes on Mobile

1. **Ground Pass (Tap Pass):**
   - Quick, reliable ball distribution.
   - For 1-2 passing (Give and Go): Pass, then immediately flick the directional stick in the running direction to send the passer forward.

2. **Stunning Pass (Swipe/Flick Pass Right/Left):**
   - Unleashes a high-speed, dipping or driven pass that cuts through defensive lines.
   - *Trade-off:* Requires a brief wind-up animation. Only execute when your midfielder has 1-2 yards of open space.

3. **Lofted Through Ball (Flick Pass Up):**
   - Floats the ball over the backline into the path of a sprinting winger or poacher.
   - Best executed by players with **Pinpoint Crossing** or **Weighted Pass** skills (e.g., De Bruyne, Alexander-Arnold).

4. **Finesse / Curled Pass:**
   - Swerves around pressing defenders to reach the opposite flank.

## Pro Passing Principles
- **Body Angle Matters:** Passing against your player's body direction causes inaccurate, slow passes. Face your target before releasing.
- **First-Time Passing:** Players equipped with the **One-touch Pass** skill can accurately redirect the ball without taking a controlling touch.
''',
        ),
        GuideArticle(
          id: 'shooting_guide',
          categoryId: 'mechanics',
          title: 'Shooting Techniques & Finishing',
          summary: 'Normal shots, Finesse curl, Stunning shots, Chip shots, and low-driven finishes.',
          difficulty: GuideDifficulty.intermediate,
          readTimeMinutes: 5,
          tags: ['Shooting', 'Finishing', 'Stunning Shot', 'Curl'],
          keyTakeaways: [
            'Finesse shot (flick down/curl) targets the far corner with high curve.',
            'Stunning shots have enormous power from distance but require wind-up space.',
            'Use Low Driven shots inside the box to prevent goalkeepers from making reflex saves.',
          ],
          markdownContent: '''
# Shooting Techniques & Finishing

Scoring consistently requires selecting the right shot type for every angle and goalkeeper position.

## Shot Variations

| Shot Type | Touch Command | Best Use Case |
|---|---|---|
| **Normal Shot** | Tap/Hold Shot | 1v1 close range, open rebounds |
| **Finesse Shot** | Flick Shot Downwards | Angled runs into the box; curling around the keeper into the far post |
| **Stunning Shot** | Flick Shot Right/Left | Uncontested shots outside the penalty box |
| **Chip Shot** | Flick Shot Upwards | When goalkeeper rushes off their line |
| **Low-Driven Shot** | Double-tap Shot | Tight box angles; difficult for tall keepers to reach |

## Mastering the Finesse Shot
- Position the player on their strong foot (e.g., Right-footed winger on the left wing).
- Cut inside at a 45-degree angle.
- Charge power to 50-65% while flicking the shot button down.
- Players with **Long-range Curler** and **Finishing 85+** will score consistently.

## Common Finishing Mistakes
- Overpowering shots inside the 6-yard box (leads to hitting the crossbar).
- Shooting while sprinting full speed without steadying the ball.
''',
        ),
        GuideArticle(
          id: 'dribbling_guide',
          categoryId: 'mechanics',
          title: 'Dribbling, Sharp Touch & Finesse Dribble',
          summary: 'Control the tempo with walking dribbles, directional bursts, and Finesse Dribble in tight spaces.',
          difficulty: GuideDifficulty.intermediate,
          readTimeMinutes: 4,
          tags: ['Dribbling', 'Finesse Dribble', 'Sharp Touch', 'Agility'],
          keyTakeaways: [
            'Do NOT hold sprint constantly. Walking dribble offers the tightest turning radius.',
            'Sharp Touch (double flick sprint) creates explosive separation past flat-footed defenders.',
            'Finesse Dribble keeps your chest facing the opponent for agile micro-touches.',
          ],
          markdownContent: '''
# Dribbling, Sharp Touch & Finesse Dribble

Dribbling in eFootball is about tempo control, deception, and sudden acceleration rather than constant skill spamming.

## 1. The Normal & Slow Dribble
- **Release Sprint:** Gently tilt the virtual joystick. The ball stays glued to the boots.
- Use this to bait defenders into lunging, then change direction into the open space.

## 2. Sharp Touch (Explosive Burst)
- While moving, flick the Dash button and directional stick simultaneously in your desired sprint path.
- The player kicks the ball 3-5 yards ahead and accelerates rapidly.
- *Best used:* When you have open grass ahead on the wing or after beating a defender with a body feint.

## 3. Finesse Dribble
- Activated by light drag touches on the control stick without pressing Dash.
- Keeps your player facing forward while moving laterally.
- Essential for manipulating defenders on the edge of the penalty box.
''',
        ),
        GuideArticle(
          id: 'defending_guide',
          categoryId: 'mechanics',
          title: 'Defensive Fundamentals: Match-up & Pressing',
          summary: 'Stop conceding counter-attacks with Match-up positioning, manual switching, and disciplined pressing.',
          difficulty: GuideDifficulty.beginner,
          readTimeMinutes: 5,
          tags: ['Defending', 'Match-up', 'Tackling', 'Interceptions'],
          keyTakeaways: [
            'Match-up is the #1 defensive tool: it intercepts passes and blocks shots automatically.',
            'Avoid pulling Center Backs out of the backline; defend with Defensive Midfielders (CDMs).',
            'Use Call 2nd Defender selectively to trap wingers near the touchline.',
          ],
          markdownContent: '''
# Defensive Fundamentals: Match-up & Pressing

Great defense wins tournaments. The key is staying patient and maintaining defensive shape.

## 1. The Match-Up Command
- **How to execute:** Hold the **Match-up** button (or slide the Pressure button depending on control layout).
- **Effect:** Your defender lowers their center of gravity, faces the attacker, and automatically extends a leg to intercept passes and block shot trajectories.
- **Rule:** Use Match-up inside your defensive third rather than sprinting straight at the attacker.

## 2. Pressure & Call 2nd Defender
- **Single Pressure:** Pressing the button sends your active player to challenge for the ball.
- **Call 2nd Defender (Flick Pressure Up):** A teammate presses the ball carrier while you manually cover the passing lane with your active cursor.
- *Caution:* Never 2nd-man press in central defense, as it pulls CBs out of position and opens easy through-ball channels.

## 3. Manual Player Switching
- Switch players early using flick switching towards the defender you want to position.
- Track runners before through-passes are played over the top.
''',
        ),
      ],
    ),

    // 3. Skill Moves
    GuideCategory(
      id: 'skill_moves',
      title: 'Skill Moves & Execution',
      subtitle: 'Double Touch, Marseille Turn, Chop Turn, and skill training',
      icon: Icons.flare,
      accentColor: Color(0xFFE2E8F0),
      articles: [
        GuideArticle(
          id: 'skill_moves_breakdown',
          categoryId: 'skill_moves',
          title: 'Top Skill Moves & When to Use Them',
          summary: 'Step-by-step touch execution for the most effective skill moves in competitive play.',
          difficulty: GuideDifficulty.advanced,
          readTimeMinutes: 5,
          tags: ['Skills', 'Double Touch', 'Marseille Turn', 'Feints'],
          keyTakeaways: [
            'Double Touch is the most reliable 1v1 move in eFootball Mobile.',
            'Marseille Turn is ideal for spinning away from high-press midfielders.',
            'A player MUST have the specific skill in their profile to execute it.',
          ],
          markdownContent: '''
# Top Skill Moves & Execution

Skill moves should be used with purpose to create passing angles or slip past a committing defender.

## 1. Double Touch (The King of Skills)
- **Required Skill:** *Double Touch*
- **Execution:** Flick the directional stick in the dribble direction while tapping the Dash button.
- **Why it works:** Instantly shifts the ball from one foot to the other, gliding past tackles.
- **Special Combo:** Players with *Double Touch + Flip Flap + Sole Control* perform the **Special Double Touch** (Neymar/Iniesta style), which is faster and smoother.

## 2. Marseille Turn (Roulette 360)
- **Required Skill:** *Marseille Turn*
- **Execution:** Rotate the stick 90 degrees while pressing Dash.
- **Best Use:** When a defender is chasing you from the side/back in midfield.

## 3. Chop Turn & Cut Behind
- **Required Skill:** *Chop Turn* or *Cut Behind & Turn*
- **Execution:** Fake shot (tap shot then immediately tap pass) + directional angle.
- **Best Use:** On the wing to suddenly cut inside onto the attacker's dominant foot.

## 4. Fake Shot
- **Available to ALL players.**
- **Execution:** Tap Shot, then immediately tap Pass and point the stick.
- **Effect:** Freezes goalkeepers and lunging defenders completely.
''',
        ),
      ],
    ),

    // 4. Formations & Tactics
    GuideCategory(
      id: 'tactics',
      title: 'Formations & Tactics',
      subtitle: 'Meta formations, Team Playstyles, Fluid Formations, and Overload',
      icon: Icons.dashboard_customize,
      accentColor: Color(0xFF00E676),
      articles: [
        GuideArticle(
          id: 'formation_breakdown',
          categoryId: 'tactics',
          title: 'Meta Formations Comparison & Roles',
          summary: 'Deep dive into 4-2-2-2, 4-3-3, 4-2-3-1, and 4-4-2 setups with pros, cons, and player requirements.',
          difficulty: GuideDifficulty.intermediate,
          readTimeMinutes: 6,
          tags: ['Formations', '4-2-2-2', '4-3-3', 'Tactics', 'Game Plan'],
          keyTakeaways: [
            '4-2-2-2 offers the best defensive solidity with a double pivot and two dynamic strikers.',
            '4-3-3 provides maximum pitch width and high pressing capabilities.',
            'Always pair an Anchor Man CDM with an Orchestrator or Box-to-Box midfielder.',
          ],
          markdownContent: '''
# Meta Formations Comparison & Roles

Choosing the right formation establishes your team's tactical identity.

## Popular Formations Overview

| Formation | Structure | Strengths | Weaknesses |
|---|---|---|---|
| **4-2-2-2 (Wide)** | 4 Def, 2 CDM, 2 AMF/LMF/RMF, 2 CF | Midfield density, lethal counter-attacks, double pivot shield | Can be vulnerable on wide wing overlaps |
| **4-3-3** | 4 Def, 1 CDM, 2 CMF, 2 Wingers, 1 CF | Natural width, high pressing, isolates fullbacks 1v1 | Midfield can be outnumbered against 2 CDMs |
| **4-2-3-1** | 4 Def, 2 CDM, 3 AMF, 1 CF | Elite defensive structure, creative central link-up | Lone striker can become isolated |
| **4-4-2 (Flat)** | 4 Def, 4 Mid, 2 CF | Perfectly balanced, simple to learn, 2 strikers pressure CBs | Central midfield can feel flat |
| **3-4-3 / 3-5-2** | 3 CB, 2 Wingbacks, 2-3 Mid, 2-3 Att | Overloads midfield and attacking thirds | High risk on counter-attacks down the flanks |

## Key Midfield Combinations
- **The Double Pivot:** Always pair an **Anchor Man** (stays deep, protects CBs) with a **Box-to-Box** (high work rate end-to-end) or **Orchestrator** (deep playmaker).
- **Attacking Midfielders (AMF):** Use a **Hole Player** (makes late runs into the box to score) alongside a **Creative Playmaker**.
''',
        ),
        GuideArticle(
          id: 'fluid_formations',
          categoryId: 'tactics',
          title: 'Fluid Formations & Overload Playstyle (Season 2027)',
          summary: 'Master the v6.0+ features: dynamic formation shifts between attack and defense, and the Overload playstyle.',
          difficulty: GuideDifficulty.advanced,
          readTimeMinutes: 5,
          tags: ['Season 2027', 'Fluid Formations', 'Overload', 'Playstyles'],
          keyTakeaways: [
            'Fluid Formations let your team defend in 4-4-2 and attack in 3-2-5 automatically.',
            'Overload packs the ball side to create numerical superiority for rapid short passing.',
          ],
          markdownContent: '''
# Fluid Formations & Overload Playstyle

The latest season introduced advanced tactical tools that mirror modern real-world football.

## 1. Fluid Formations
- **What it is:** Allows you to configure two distinct formations:
  - **In Possession (Attack):** Wingbacks push high, one CDM drops between CBs (e.g., 3-2-4-1).
  - **Out of Possession (Defense):** Team compresses into a compact low-block (e.g., 4-4-2 or 5-3-2).
- **How to set up:** In Game Plan > Tactics > Enable Fluid Formation.

## 2. The Overload Playstyle
- **Concept:** When your team has the ball, players shift dynamically towards the active flank or central corridor.
- **Advantage:** Creates 3v2 and 4v3 overloads, making it easy to play short triangles and retain possession against aggressive pressing.
- **Counter-measure:** Watch out for sudden long switches of play to the unguarded weak side.
''',
        ),
      ],
    ),

    // 5. Player Attributes & Building
    GuideCategory(
      id: 'attributes',
      title: 'Player Attributes & Progression',
      subtitle: 'Stat breakdowns, progression points, boosters, and skill training',
      icon: Icons.analytics_outlined,
      accentColor: Color(0xFF00E5FF),
      articles: [
        GuideArticle(
          id: 'player_attributes',
          categoryId: 'attributes',
          title: 'Attribute Guide: What Every Stat Actually Does',
          summary: 'Understand Physical Contact, Defensive Engagement, Tight Possession, Acceleration vs Speed, and Weak Foot.',
          difficulty: GuideDifficulty.beginner,
          readTimeMinutes: 5,
          tags: ['Attributes', 'Stats', 'Physicality', 'Weak Foot'],
          keyTakeaways: [
            'Speed is top sprint velocity; Acceleration is how fast the player reaches top speed.',
            'Physical Contact wins shoulder-to-shoulder 50/50 duels.',
            'Weak Foot Accuracy ensures consistent passing from awkward angles.',
          ],
          markdownContent: '''
# Attribute Guide: What Every Stat Actually Does

Knowing how attributes translate onto the pitch helps you train players effectively.

## Key Attribute Explanations

- **Pace (Speed vs. Acceleration):**
  - **Speed:** Maximum running speed over long distances (crucial for counter-attacking wingers).
  - **Acceleration:** First-step burst and reaction time (crucial for center backs and agile dribblers).

- **Dribbling & Ball Control:**
  - **Ball Control:** First touch quality when trapping high balls or through passes.
  - **Dribbling:** Speed and control while moving with the ball.
  - **Tight Possession:** Maneuverability and turn speed in tight phone-booth spaces.

- **Passing:**
  - **Low Pass:** Speed and accuracy of ground balls.
  - **Lofted Pass:** Trajectory, dip, and crossing accuracy.

- **Physicality & Defense:**
  - **Physical Contact:** Ability to hold off challenges and win physical 50/50 collisions.
  - **Balance:** Ability to stay on feet while being bumped or tackled.
  - **Defensive Awareness & Engagement:** Reaction speed to loose balls and tracking intensity.

## Weak Foot Rating Guide
- **Weak Foot Usage (0-3):** How frequently the player attempts weak-foot actions.
- **Weak Foot Accuracy (0-3):** How accurate shots and passes are with the non-dominant foot.
- *Aim for:* 2★+ accuracy on defenders and 3★ on central midfielders and strikers.
''',
        ),
        GuideArticle(
          id: 'progression_training',
          categoryId: 'attributes',
          title: 'Progression Points, Boosters & Skill Fusion',
          summary: 'How to allocate progression points, reset builds for free, add boosters, and transfer skills.',
          difficulty: GuideDifficulty.intermediate,
          readTimeMinutes: 4,
          tags: ['Progression', 'Training', 'Boosters', 'Skill Training'],
          keyTakeaways: [
            'Progression point resets are now free; experiment with customized builds.',
            'Boosters can push card stats past 99 up to 105+ OVR.',
            'Use Skill Training items to add crucial skills like One-touch Pass and Interception.',
          ],
          markdownContent: '''
# Progression Points, Boosters & Skill Fusion

Maximize your squad's ceiling with optimized training builds.

## 1. Allocating Progression Points
- Match EXP and Training Programs grant Progression Points.
- **Auto-allocate vs. Custom:** Auto-allocate maximizes Overall Rating (OVR), but **Custom allocation** builds specialized weapons (e.g., boosting Speed + Physical Contact on a winger instead of unused defensive stats).
- **Free Resets:** Resetting points is free in current versions. Feel free to rebuild players for different playstyles.

## 2. Boosters
- Epic and Highlight cards feature Boosters (+1 to +3 to specific stat groups).
- Booster Tokens can activate additional stat increases, allowing elite cards to reach 100+ stats.

## 3. Skill & Position Training
- Each player can learn up to **5 additional skills**.
- **Priority Skills for Attackers:** Double Touch, First-time Shot, Long-range Curler, One-touch Pass.
- **Priority Skills for Midfielders:** One-touch Pass, Through Passing, Interception, Man Marking.
- **Priority Skills for Defenders:** Blocker, Interception, Aerial Superiority, Sliding Tackle.
''',
        ),
      ],
    ),

    // 6. Meta & Common Mistakes
    GuideCategory(
      id: 'meta_strategy',
      title: 'Meta Strategies & Mistakes',
      subtitle: 'Competitive gameplay tips, common pitfalls, and daily training drills',
      icon: Icons.military_tech_outlined,
      accentColor: Color(0xFFFF1744),
      articles: [
        GuideArticle(
          id: 'common_mistakes',
          categoryId: 'meta_strategy',
          title: '7 Common Mistakes Costing You Matches',
          summary: 'Identify and fix sprint addiction, reckless lunges, poor stamina management, and bad economy spending.',
          difficulty: GuideDifficulty.beginner,
          readTimeMinutes: 4,
          tags: ['Mistakes', 'Tips', 'Defense', 'Stamina'],
          keyTakeaways: [
            'Stop holding Sprint on defense; it makes changing direction impossible.',
            'Substitute tired fullbacks and central midfielders around the 65th minute.',
            'Never blindly pass forward into a congested center.',
          ],
          markdownContent: '''
# 7 Common Mistakes Costing You Matches

Fixing these seven fundamental errors will immediately boost your win rate in division matches.

## 1. Sprint Button Addiction
- **The Mistake:** Holding Dash 100% of the match.
- **Why it hurts:** Increases heavy touches, reduces passing accuracy by 40%, and drains stamina by the 60th minute.
- **The Fix:** Sprint only into open green space. Release sprint when approaching opponents.

## 2. Pulling Center Backs Out of Position
- **The Mistake:** Switching to your CB and rushing forward to tackle a midfielder.
- **Why it hurts:** Leaves a giant gap for easy through balls.
- **The Fix:** Control your CDM to track back. Let AI center backs maintain the offside line.

## 3. Ignoring Weak Foot Angles
- **The Mistake:** Attempting a finesse shot with an inverted winger on their 1★ weak foot.
- **The Fix:** Cut back to their strong foot or choose a low ground pass across the box.

## 4. Neglecting Substitutions
- Tired players lose up to 30% of their Speed, Acceleration, and Defensive Awareness in the final 20 minutes.
- Bring on **Super-sub** attackers and fresh CDMs at the 65-70 minute mark.

## 5. Rushing Goal Kicks & Clearances
- Always scan the mini-radar before taking goal kicks to avoid passing straight to an opponent striker.
''',
        ),
        GuideArticle(
          id: 'training_routines',
          categoryId: 'meta_strategy',
          title: 'Daily Practice Drills & Routines',
          summary: '15-minute daily practice routine to sharpen your 1v1 dribbling, free kicks, and match-up anticipation.',
          difficulty: GuideDifficulty.intermediate,
          readTimeMinutes: 4,
          tags: ['Practice', 'Drills', 'Free Kicks', 'Training'],
          keyTakeaways: [
            'Use Exhibition / Free Training mode to practice skill moves before ranked matches.',
            'Set AI difficulty to Legend to train defensive patience.',
          ],
          markdownContent: '''
# Daily Practice Drills & Routines

Consistent 10-15 minute warmups build muscle memory for tournament pressure.

## 15-Minute Daily Routine

1. **Free Training (5 minutes):**
   - Practice 10 consecutive Double Touches in both directions.
   - Practice 5 Finesse Shots from the left edge of the box and 5 from the right.
   - Practice curling free kicks over the wall into the top corners.

2. **Exhibition vs. Legend AI (10 minutes / 1 match):**
   - Focus entirely on **defensive discipline**: try to concede zero goals without using the slide tackle button once.
   - Restrict yourself to short, patient build-up passing (target 65%+ possession).
''',
        ),
      ],
    ),

    // 7. Set Pieces
    GuideCategory(
      id: 'set_pieces',
      title: 'Set Pieces & Dead Balls',
      subtitle: 'Corners, free kicks, penalties, and defensive positioning',
      icon: Icons.flag_outlined,
      accentColor: Color(0xFFFFD600),
      articles: [
        GuideArticle(
          id: 'free_kicks_corners',
          categoryId: 'set_pieces',
          title: 'Free Kicks & Corner Kick Routines',
          summary: 'Curling free kicks over the wall, near-post corner flicks, and short corner overloads.',
          difficulty: GuideDifficulty.intermediate,
          readTimeMinutes: 4,
          tags: ['Free Kicks', 'Corners', 'Set Pieces', 'Curl'],
          keyTakeaways: [
            'Draw a curved arc on screen to bend direct free kicks around or over walls.',
            'Target tall CBs with Aerial Superiority at the near post on corners.',
          ],
          markdownContent: '''
# Free Kicks & Corner Kick Routines

Dead ball situations are guaranteed goal-scoring opportunities when executed properly.

## Direct Free Kicks (Mobile Swipe)
- **Aiming:** Align the camera gap between the wall defenders and the post.
- **Swiping Gesture:** Swipe your finger in a smooth curve upwards and towards the target corner.
- **Swipe Speed:** A fast swipe produces high power with dip; a slow, high-curvature swipe maximizes spin over the wall.
- **Ideal Takers:** Players with **Place Kicking 85+** and **Curl 85+** (e.g., Messi, Beckham, Pirlo).

## Corner Kick Routines
1. **Near-Post Flick On:**
   - Inswinging cross aimed at the front edge of the 6-yard box.
   - Select a player with high **Heading** and **Aerial Superiority** to flick the ball toward the back post.
2. **Short Corner Overload:**
   - Call 2nd runner, pass short, and cut inside to execute a curling Finesse Shot from the corner of the penalty area.
''',
        ),
      ],
    ),

    // 8. Team Building & Contracts
    GuideCategory(
      id: 'team_building',
      title: 'Team Building & Contracts',
      subtitle: 'Card rarities, Dream Team, Nominating Contracts, and manager synergy',
      icon: Icons.groups,
      accentColor: Color(0xFF00E5FF),
      articles: [
        GuideArticle(
          id: 'card_rarity_contracts',
          categoryId: 'team_building',
          title: 'Card Types, Rarity & Smart Acquisitions',
          summary: 'Standard, Highlight, Epic, and Legendary cards explained. How to use Nominating Contracts and Chance Deals.',
          difficulty: GuideDifficulty.beginner,
          readTimeMinutes: 5,
          tags: ['Dream Team', 'Cards', 'Contracts', 'Epic', 'GP'],
          keyTakeaways: [
            'Contracts no longer expire; players can be used indefinitely.',
            'Save Nominating Contracts for 5★ featured players that fit your primary playstyle.',
          ],
          markdownContent: '''
# Card Types, Rarity & Smart Acquisitions

Building a championship Dream Team requires understanding card tiers and economy management.

## Card Rarity Tiers

- **Standard Cards:** Base players signed with GP. Fully customizable stat progression.
- **Highlight Cards:** Top performers from real-world matchdays with pre-boosted stats.
- **Epic & Big Time Cards:** Historic legendary players with custom animations, unique playstyles, and Booster stats exceeding 100+ OVR.
- **Show Time Cards:** Feature exclusive fortress/phenomenal finishing skills.

## Contract & Acquisition Mechanisms
- **No Contract Expiration:** Modern eFootball removed the 365-day contract expiration timer. All signed players remain in your squad forever.
- **Nominating Contracts:** Earned via Match Pass. Use them to pick specific marquee players from limited-time campaign pools.
- **GP vs. Coins:** Use GP for standard players, managers, and position training; reserve Coins exclusively for high-tier Epic packs.
''',
        ),
      ],
    ),

    // 9. Progression & Economy
    GuideCategory(
      id: 'progression_economy',
      title: 'Progression, Economy & Gacha',
      subtitle: 'Match Pass, seasonal campaigns, GP optimization, and f2p strategies',
      icon: Icons.monetization_on_outlined,
      accentColor: Color(0xFF00E676),
      articles: [
        GuideArticle(
          id: 'economy_f2p_guide',
          categoryId: 'progression_economy',
          title: 'F2P Guide: Maximize Coins, EXP & Rewards',
          summary: 'How free-to-play managers can build a 3100+ Team Strength squad without spending money.',
          difficulty: GuideDifficulty.beginner,
          readTimeMinutes: 4,
          tags: ['F2P', 'Coins', 'Match Pass', 'Rewards', 'Economy'],
          keyTakeaways: [
            'Complete all weekly AI Tour and Challenge Events for free Coins and Training Programs.',
            'Never spend Coins on single 100-coin pulls; save for guaranteed 50-player or 150-player boxes.',
          ],
          markdownContent: '''
# F2P Guide: Maximize Coins, EXP & Rewards

You can easily compete in Division 1 and tournament play as a Free-to-Play (F2P) manager.

## Weekly Resource Checklist
1. **PVP Events (eFootball League & Challenges):** Clear 50-100 Coins weekly.
2. **Tour Events (vs. AI):** Earn 30,000+ GP, 10,000 EXP programs, and Chance Deal tickets.
3. **Daily Login & Game Bonus:** Complete daily penalty kicks to earn Epic player rewards.
4. **Match Pass:** Regular Match Pass is free; discounts are offered periodically on Value and Premium passes.
''',
        ),
      ],
    ),

    // 10. Roadmap & Community
    GuideCategory(
      id: 'community_roadmap',
      title: 'Learning Roadmap & Community',
      subtitle: 'Step-by-step master roadmap, creators, Reddit, and tournament prep',
      icon: Icons.explore_outlined,
      accentColor: Color(0xFFE2E8F0),
      articles: [
        GuideArticle(
          id: 'learning_roadmap',
          categoryId: 'community_roadmap',
          title: 'The eFootball Mastery Roadmap',
          summary: 'From beginner to Division 1 champion: the 5-stage progression roadmap.',
          difficulty: GuideDifficulty.beginner,
          readTimeMinutes: 5,
          tags: ['Roadmap', 'Progression', 'Community', 'Ranked'],
          keyTakeaways: [
            'Master Match-up and 1-2 passing before attempting complex skill moves.',
            'Join club tournaments and community scrims to test tactics under pressure.',
          ],
          markdownContent: '''
# The eFootball Mastery Roadmap

Follow this 5-stage structured roadmap to develop high-level competitive fundamentals.

## Stage 1: Fundamentals (Days 1–7)
- Learn Classic Touch Controls and turn off Smart Assist.
- Complete Skill-Up tutorial drills.
- Practice low ground passing and Match-up defending.

## Stage 2: Squad Foundation (Days 8–14)
- Pick a primary Team Playstyle (Possession Game, Quick Counter, or Overload).
- Set up a balanced 4-2-2-2 or 4-3-3 formation.
- Train all starting XI players to max level with customized points.

## Stage 3: Technical Skills (Days 15–30)
- Master the **Double Touch** and **Fake Shot**.
- Practice manual player switching during opponent counters.
- Learn far-post Finesse Shots from 45-degree angles.

## Stage 4: Competitive Meta (Month 2+)
- Introduce **Fluid Formations** (defend in 4-4-2, attack in 3-2-5).
- Master timed **Stunning Passes** to unlock stubborn defenses.
- Analyze your H2H match history and heatmaps in this app!

## Top Community Resources
- **Reddit:** `r/pesmobile` & `r/efootball` for weekly meta analysis.
- **YouTube:** PES Dude, Prof BOF, and Pro Keeper for skill tutorials.
- **Database:** eFHUB and FIFPlay for player stat caps and booster calculations.
''',
        ),
      ],
    ),
  ];

  static GuideArticle? findArticleById(String id) {
    for (final category in categories) {
      for (final article in category.articles) {
        if (article.id == id) return article;
      }
    }
    return null;
  }

  static List<GuideArticle> searchArticles(String query) {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase();
    final results = <GuideArticle>[];

    for (final category in categories) {
      for (final article in category.articles) {
        if (article.title.toLowerCase().contains(q) ||
            article.summary.toLowerCase().contains(q) ||
            article.tags.any((tag) => tag.toLowerCase().contains(q)) ||
            article.markdownContent.toLowerCase().contains(q)) {
          results.add(article);
        }
      }
    }
    return results;
  }
}

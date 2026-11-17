# Google Play: Delivery Hassen listing

Everything the Play Console asks for, ready to paste. The images are in this
folder.

Package: `tn.hssan.delivery` · Default language: **French (fr-FR)** ·
Countries: **Tunisia** · Price: **Free**

## Main store listing

**App name** (30 characters max):

```
Delivery Hassen
```

**Short description** (80 characters max):

```
Repas, courses, colis et factures livrés chez vous à Bizerte.
```

**Full description** (4,000 characters max):

```
Delivery Hassen : la livraison à Bizerte, as fast as you think.

Commandez vos repas, faites vos courses, envoyez un colis ou faites payer vos factures : un livreur s'occupe de tout, et vous payez en espèces à la livraison.

RESTAURANTS
• Les restaurants de Bizerte, classés par envie : sucré, salé, fast food, pizza…
• Composez votre plat : sauces, suppléments, boisson au choix
• Recommandez vos plats préférés en un geste

COURSES
• Les produits du quotidien, livrés chez vous

COLIS
• Un envoi rapide d'un point à un autre de la ville

FACTURES ET MANDATS
• Un livreur passe chez vous, paie vos factures au guichet (électricité, eau, téléphone, internet) et vous rapporte le reçu
• Il peut aussi envoyer un mandat pour vous

SUIVI EN DIRECT
• Suivez votre livreur en direct sur la carte, jusqu'à votre porte
• Une notification à chaque étape

PAIEMENT À LA LIVRAISON
• Aucune carte bancaire : vous payez en espèces au livreur

Vous êtes livreur Delivery Hassen ? Connectez-vous avec le compte créé par l'administrateur pour recevoir vos livraisons.

Une question ? contact@deliveryhassan.tn
```

**Graphics**:

| Play Console field | File |
|---|---|
| App icon (512 × 512, 32-bit PNG) | `icon-512.png` |
| Feature graphic (1024 × 500) | `feature-graphic.png` |
| Phone screenshots (2 to 8; 1080 × 1920) | `phone-1-home.png`, `phone-2-list.png`, `phone-3-menu-pizza.png`, `phone-4-tracking.png` |

The screenshots show the real catalogue (restaurants, dishes and photos as
they were in production on 17 November 2026). The order on the tracking
screen is a test order, made on a local copy: no real order was placed.

## Store settings

- **App category**: Food & Drink
- **Tags**: Food delivery, Grocery delivery
- **Email**: `contact@deliveryhassan.tn` (shown publicly; must receive mail)
- **Website**: `https://deliveryhassan.tn`
- **Phone**: optional; leave empty unless Hassan wants it public.

## App content

Play Console → *Policy and programs* → *App content*.

| Section | Answer |
|---|---|
| Privacy policy | `https://deliveryhassan.tn/confidentialite.html` |
| Ads | **No**, the app has no ads |
| App access | **All or some functionality is restricted**: give a test client account (see below) |
| Content rating | See below |
| Target audience | **18 and over** only (keeps the app out of the Families program) |
| News app | No |
| Health apps | My app does not have any health features |
| Financial features | My app doesn't provide any financial features (no money moves through the app; customers pay the courier in cash) |
| Government app | No |
| Data safety | See below |
| Account deletion URL | `https://deliveryhassan.tn/suppression-compte.html` |

### App access: the test account

Google's reviewers must be able to log in. Before submitting:

1. In the app, create a client account just for them (any unused Tunisian
   number, a strong password, name "Google Review").
2. In *App access*, add the instructions:
   `Connectez-vous avec ce numéro et ce mot de passe. Login with this phone number and password.`
   and type the number and password **in the Play Console only**: never in
   this repository or in a chat.

### Content rating (IARC questionnaire)

- Email: `contact@deliveryhassan.tn`
- Category: **All other app types**
- Violence, sexuality, language, drugs, gambling, horror: **No** to all
- Does the app let users interact or exchange content? **No** (no chat between users)
- Does the app share the user's current location with other users? **Yes**
  (the client sees the courier's position during a delivery)
- Does the app let users buy digital goods? **No** (deliveries are physical,
  paid in cash)
- Expected rating: **3+ / Everyone**

### Data safety

General questions:

- Does your app collect or share any of the required user data types? **Yes**
- Is all the user data collected by your app encrypted in transit? **Yes** (HTTPS)
- Which of the following methods of account creation does your app support?
  **Username and password** (phone number + password)
- Delete account URL: `https://deliveryhassan.tn/suppression-compte.html`
- Can users request that some or all of their data be deleted? **Yes**

Data types. For all of them: **Collected: Yes · Shared: No** (sending an
order to its courier and restaurant is part of the service the user asks
for, which Google does not count as "sharing", and neither are service
providers such as the hosting) · **Processed ephemerally: No**.

| Category → type | Required or optional | Purposes |
|---|---|---|
| Location → Approximate location | Optional | App functionality |
| Location → Precise location | Optional | App functionality |
| Personal info → Name | Required | App functionality, Account management |
| Personal info → Phone number | Required | App functionality, Account management |
| Personal info → Address | Required | App functionality |
| Personal info → Other info (bill references, money-order recipient's name and number, parcel recipient) | Optional | App functionality |
| Financial info → Purchase history (orders) | Required | App functionality |
| Photos and videos → Photos (bill photo, only if the user adds one) | Optional | App functionality |
| App info and performance → Crash logs | Required | App functionality |
| App info and performance → Diagnostics | Required | App functionality |
| Device or other IDs → Device or other IDs (notification token) | Optional | App functionality |

Not collected: contacts, messages, emails, calendar, audio, files, web
history, health, credit cards or bank details, installed apps.

## Publishing steps

1. **Account**: Hassan's personal developer account ($25), identity verified.
2. **Signing**: the upload keystore and the 4 `ANDROID_UPLOAD_*` GitHub
   secrets (see `.github/workflows/android-release.yml`). The next Android
   build then produces the `hssan-delivery-aab` artifact: that `.aab` is what
   goes to Play.
3. **Create the app** in the Play Console: name *Delivery Hassen*, default
   language French, *App*, *Free*.
4. Fill in everything above (*Main store listing*, *Store settings*, *App content*).
5. **Internal testing**: upload the `.aab`, add yourselves as testers,
   install it from the Play Store link and check that it works.
6. **Closed testing** (required for personal accounts): at least
   **12 testers** opted in for **14 days in a row**. Their Gmail addresses go
   into a testers list; they join through the opt-in link.
7. After 14 days: **Apply for production** in the Dashboard, answer the
   questions about the test, then create the production release (Tunisia).
   Google's review usually takes a few days.

## Before submitting: the website

The URLs above must work. They are served by the server's Caddy from
`deploy/site` once:

- DNS has **A records** for `deliveryhassan.tn` and `www.deliveryhassan.tn`
  → `149.56.208.127` (replace OVH's default A record);
- the server's `deploy/.env` has `SITE_DOMAIN=deliveryhassan.tn`;
- the server runs the version of `main` that contains `deploy/site`
  (`git pull`, then `docker compose -f docker-compose.prod.yml up -d`);
- `contact@deliveryhassan.tn` receives mail (an OVH email redirection to
  Hassan's address is enough).

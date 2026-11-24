## What is Sales Station?

Sales Station is a local workspace for technical sales. Use it to track customer opportunities, prepare meeting decks, and follow up after meetings.

- **Home and Pipeline** show what’s due and where each opportunity stands.
- **Projects** keeps the latest discussion, next action, owner, and due date together.
- **Decks and Success stories** let you build a customer presentation from a Master deck and insert editable example slides.
- **Boss report** brings together updates you’ve marked for your manager.

## Try it in 10 minutes

1. On GitHub, select **Code → Download ZIP**. Extract the ZIP to a regular folder, then open `index.html` in desktop Chrome or Edge.
2. For this demo, select **KR Korea → Link folder…** and choose `andes-data-korea` inside your extracted copy. For Japan, select **JP Japan** and choose `andes-data-japan`.
3. Open **Accounts** and find **Demo Meridian KR** or **Demo Meridian JP**. Open the sample project and use **Update progress** to record a fictional next step.
4. Go to **Decks → New customer** and start from the Master deck. In **Add slide → Success stories**, preview and insert a sample page. Edit its title in your deck.
5. Open **Boss report** to see how updates marked for your manager appear in the weekly report.

## Where your data lives

AI helped build the program. This GitHub repository contains the program and fictional test data. Sales Station runs on your computer. For real sales work, link your approved local workspace folder and keep live records there.
# Sales Station

Run index.html in desktop Chrome or Edge. The two andes-data folders in this
checkout contain fictional test records. Use a separate browser profile and a
disposable copy of a fixture folder when testing folder writes.

Keep confidential records and backups in the separate, local-only workspace.
Connect that workspace from the application after checking the full directory
path. A browser cache is specific to its browser profile and app database.
The clean build uses a new database name for each region. Verify existing
decks and media after migration, especially images that previously depended on
assets embedded in the old program file.

For program updates in a clean checkout on main, run git pull --ff-only origin
main. The checkout and its fixture folders are separate from the confidential
workspace.

The fixture includes a fictional account, project, history event, master,
customer deck, FAE reference and success story in each workspace. Background
sync and private workspace migrations require separate on-device verification.

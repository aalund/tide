# Tidevand – Grenaa (GitHub Pages)

Denne mappe er klar til at blive publiceret med GitHub Pages.

## Indhold

- `index.html` – den færdige statiske side
- `.nojekyll` – sikrer at GitHub Pages serverer siden direkte

## Hurtigste måde

### Mulighed A – nyt dedikeret repository

1. Opret et nyt repository på GitHub, fx `tidevand-grenaa`
2. Upload filerne fra denne mappe til repository-roden
3. Gå til **Settings → Pages**
4. Under **Build and deployment** vælg:
   - **Source:** `Deploy from a branch`
   - **Branch:** `main`
   - **Folder:** `/ (root)`
5. Gem
6. Efter kort tid får du en URL som:
   - `https://DIT-BRUGERNAVN.github.io/tidevand-grenaa/`

### Mulighed B – fra kommandolinje

Hvis du allerede har et tomt GitHub-repo klar:

```bash
cd tidevand-site
git init
git add .
git commit -m "Initial GitHub Pages site"
git branch -M main
git remote add origin https://github.com/DIT-BRUGERNAVN/tidevand-grenaa.git
git push -u origin main
```

Derefter:

1. Åbn repoet på GitHub
2. Gå til **Settings → Pages**
3. Vælg `main` + `/ (root)`

## Opdatering af tide-data

Fra workspace-roden:

```bash
./update-tidevand-grenaa.sh
```

Det opdaterer både:
- `tidevand-grenaa-v2.html`
- `tidevand-site/index.html`

Hvis siden allerede ligger på GitHub Pages, så commit og push bagefter:

```bash
git add tidevand-site/index.html update-tidevand-grenaa.sh tidevand-grenaa-v2.html
git commit -m "Update tide page"
git push
```

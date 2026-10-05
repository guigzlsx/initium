# Initium — checklist TestFlight

## Configuration Xcode / App Store Connect

- [ ] Bundle ID : `com.guillaumelsx.initium`
- [ ] Team de signature sélectionnée dans Xcode
- [ ] Certificat et provisioning profile valides
- [ ] Marketing Version : `0.1.0`
- [ ] Build : `1` (incrémenter pour chaque nouvel upload)
- [ ] App Icon `AppIcon` configurée
- [ ] Nom affiché : `Initium`
- [ ] Descriptions de confidentialité relues
- [ ] Notifications locales décrites dans les métadonnées si nécessaire

## Validation avant archive

- [ ] Build `Release` sans code DEBUG
- [ ] Suite de tests complète
- [ ] Parcours activité simple
- [ ] Parcours routine et transition
- [ ] Parcours Replan et Undo
- [ ] Calibration après trois observations
- [ ] Suppression complète des données vérifiée
- [ ] FR et EN vérifiés
- [ ] Mode clair et sombre vérifiés
- [ ] Dynamic Type, VoiceOver et Reduce Motion vérifiés
- [ ] Petit écran et grand écran vérifiés

## Archive

1. Ouvrir `Initium.xcodeproj`.
2. Sélectionner la target `Initium` et une équipe de signature.
3. Choisir `Any iOS Device (arm64)`.
4. Exécuter `Product > Archive`.
5. Vérifier le bundle ID, la version et le build dans Organizer.
6. Distribuer vers TestFlight après validation de l’archive.

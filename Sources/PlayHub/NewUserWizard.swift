import SwiftUI

/// Full-screen, step-by-step sign-up flow for a new player (name → gamer tag → avatar →
/// color → favorite genre → review). Fully opaque: nothing of the console UI shows behind it.
/// Controller input is handled by `ProfileEditorController.handle`; taps work too.
struct NewUserWizardView: View {
    @EnvironmentObject var settings: AppSettings
    @ObservedObject var editor: ProfileEditorController
    let onClose: () -> Void

    private var accent: Color { editor.accentChoice.color }
    private var step: NewUserStep { editor.wizardStep }
    private var stepCount: Int { NewUserStep.allCases.count }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            WavesView(accent: accent, intensity: 0.5, sparks: true).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 80)
                    .padding(.top, 40)

                Spacer(minLength: 20)

                stepContent
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(x: 40)),
                        removal: .opacity.combined(with: .offset(x: -40))
                    ))
                    .frame(maxWidth: 820)

                Spacer(minLength: 20)

                buttons
                    .padding(.horizontal, 80)
                    .padding(.bottom, 18)

                HintBar(items: hints)
            }

            if let field = editor.activeField {
                OnScreenKeyboardView(editor: editor, field: field, accent: accent)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: step)
        .animation(.spring(response: 0.28, dampingFraction: 0.84), value: editor.activeField)
        .animation(.easeInOut(duration: 0.3), value: editor.accentChoice)
    }

    // MARK: - Header with progress

    private var header: some View {
        HStack(spacing: 16) {
            LogoMark(accent: accent).frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Yeni Oyuncu"))
                    .font(.system(size: 26, weight: .bold))
                Text(L("Adım \(step.rawValue + 1) / \(stepCount)"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            HStack(spacing: 8) {
                ForEach(NewUserStep.allCases, id: \.rawValue) { s in
                    Capsule()
                        .fill(s.rawValue <= step.rawValue ? accent : Color.white.opacity(0.18))
                        .frame(width: s == step ? 44 : 22, height: 6)
                }
            }
        }
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .name:
            stepFrame(icon: "hand.wave.fill",
                      title: L("Sana nasıl seslenelim?"),
                      subtitle: L("Bu ad karşılama ekranında ve profilinde görünür.")) {
                textBox(value: editor.displayName, placeholder: L("Örn: Zinkx"), prefix: nil, field: .displayName)
            }
        case .gamertag:
            stepFrame(icon: "at",
                      title: L("Bir kullanıcı adı seç"),
                      subtitle: L("Kupalarda ve profilinde görünür. İstersen sonra değiştirebilirsin.")) {
                textBox(value: editor.gamertag, placeholder: L("Örn: zinkx"), prefix: "@", field: .gamertag)
            }
        case .avatar:
            stepFrame(icon: "face.smiling.fill",
                      title: L("Avatarını seç"),
                      subtitle: L("◀ ▶ ile simgeler arasında gez.")) {
                VStack(spacing: 22) {
                    HStack(spacing: 14) {
                        ForEach(Array(Avatar.allCases), id: \.self) { av in
                            let on = av == editor.avatar
                            avatarCircle(av, size: on ? 92 : 64)
                                .overlay(Circle().strokeBorder(.white.opacity(on ? 0.95 : 0), lineWidth: 3))
                                .opacity(on ? 1 : 0.55)
                                .onTapGesture { editor.avatar = av; AudioManager.shared.play(.tick) }
                        }
                    }
                    Text(editor.avatar.title)
                        .font(.system(size: 20, weight: .semibold))
                }
            }
        case .color:
            stepFrame(icon: "paintpalette.fill",
                      title: L("Rengini seç"),
                      subtitle: L("Profil kartın ve menüler bu renkle görünür.")) {
                VStack(spacing: 22) {
                    HStack(spacing: 18) {
                        ForEach(Array(AccentChoice.allCases), id: \.self) { c in
                            let on = c == editor.accentChoice
                            Circle()
                                .fill(c.color.gradient)
                                .frame(width: on ? 74 : 52, height: on ? 74 : 52)
                                .overlay(Circle().strokeBorder(.white.opacity(on ? 0.95 : 0), lineWidth: 3))
                                .shadow(color: c.color.opacity(on ? 0.7 : 0), radius: 16)
                                .onTapGesture { editor.accentChoice = c; AudioManager.shared.play(.tick) }
                        }
                    }
                    Text(editor.accentChoice.title)
                        .font(.system(size: 20, weight: .semibold))
                }
            }
        case .genre:
            stepFrame(icon: "heart.fill",
                      title: L("En sevdiğin oyun türü?"),
                      subtitle: L("İsteğe bağlı. Atlamak için R1'e bas.")) {
                HStack(spacing: 28) {
                    chevron("chevron.left") { editor.stepWizardOption(-1) }
                    Text(editor.genre.isEmpty ? L("Seçilmedi") : L(key: editor.genre))
                        .font(.system(size: 30, weight: .bold))
                        .frame(minWidth: 320)
                        .padding(.vertical, 18)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    chevron("chevron.right") { editor.stepWizardOption(1) }
                }
            }
        case .review:
            stepFrame(icon: "checkmark.seal.fill",
                      title: L("Her şey hazır!"),
                      subtitle: L("Bilgilerini kontrol et ve oturum aç.")) {
                reviewCard
            }
        }
    }

    private func stepFrame<Content: View>(icon: String, title: String, subtitle: String,
                                          @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 26) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(accent.mix(with: .white, by: 0.3))
                .shadow(color: accent.opacity(0.7), radius: 18)
            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 40, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
            }
            content()
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }

    private func textBox(value: String, placeholder: String, prefix: String?, field: ProfileFieldKind) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 4) {
                if let prefix, !value.isEmpty {
                    Text(prefix).foregroundStyle(accent.mix(with: .white, by: 0.4))
                }
                Text(value.isEmpty ? placeholder : value)
                    .foregroundStyle(.white.opacity(value.isEmpty ? 0.35 : 1))
                    .lineLimit(1)
            }
            .font(.system(size: 30, weight: .semibold))
            .frame(width: 560, height: 78)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(accent, lineWidth: 2.5))
            .shadow(color: accent.opacity(0.45), radius: 18)
            .onTapGesture { editor.openKeyboard(for: field) }

            Label(L("Yazmak için ✕ tuşuna bas"), systemImage: "keyboard")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var reviewCard: some View {
        HStack(spacing: 26) {
            avatarCircle(editor.avatar, size: 120)
                .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 3))
            VStack(alignment: .leading, spacing: 8) {
                Text(editor.displayName)
                    .font(.system(size: 34, weight: .bold))
                    .lineLimit(1)
                if !editor.gamertag.isEmpty {
                    Text("@\(editor.gamertag)")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(accent.mix(with: .white, by: 0.4))
                }
                HStack(spacing: 18) {
                    Label(editor.accentChoice.title, systemImage: "paintpalette.fill")
                    Label(editor.genre.isEmpty ? L("Seçilmedi") : L(key: editor.genre), systemImage: "heart.fill")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(28)
        .frame(width: 620)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(accent.opacity(0.7), lineWidth: 1.5))
    }

    private func avatarCircle(_ av: Avatar, size: CGFloat) -> some View {
        ZStack {
            Circle().fill(accent.gradient)
            Image(systemName: av.symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: accent.opacity(0.5), radius: 14)
    }

    private func chevron(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .bold))
                .frame(width: 56, height: 56)
                .background(Color.white.opacity(0.1), in: Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Buttons & hints

    private var buttons: some View {
        HStack(spacing: 16) {
            ActionButton(
                title: step == .name ? L("Vazgeç (○)") : L("Geri (○)"),
                icon: step == .name ? "xmark.circle" : "chevron.left.circle",
                focused: false,
                accent: accent
            ) {
                if editor.goBackInWizard() { onClose() }
            }
            Spacer()
            ActionButton(
                title: step == .review ? L("Oluştur & Giriş Yap (R1)") : L("İleri (R1)"),
                icon: step == .review ? "checkmark.circle.fill" : "chevron.right.circle.fill",
                focused: true,
                accent: accent,
                primary: true
            ) {
                if step == .review {
                    if editor.createAccount(settings: settings) { onClose() }
                } else {
                    editor.advanceWizard()
                }
            }
        }
    }

    private var hints: [HintItem] {
        var items: [HintItem] = []
        switch step {
        case .name, .gamertag:
            items.append(HintItem(symbol: "xmark.circle", text: L("Yaz")))
        case .avatar, .color, .genre:
            items.append(HintItem(symbol: "arrow.left.and.right.circle", text: L("Değiştir")))
        case .review:
            items.append(HintItem(symbol: "xmark.circle", text: L("Oluştur")))
        }
        if step != .review {
            items.append(HintItem(symbol: "r1.rectangle.roundedbottom", text: L("İleri")))
        }
        items.append(HintItem(symbol: "circle.circle", text: step == .name ? L("Vazgeç") : L("Geri")))
        return items
    }
}

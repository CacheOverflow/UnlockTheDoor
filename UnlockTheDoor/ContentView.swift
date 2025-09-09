import SwiftUI

struct ContentView: View {
    // Use lazy initialization to avoid blocking main thread
    @StateObject private var doorUnlockService = DoorUnlockService.shared
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    @StateObject private var sessionStore = SessionStore.shared
    @StateObject private var languageManager = LanguageManager.shared
    
    @State private var showingLinkInput = false
    @State private var linkInput = ""
    @State private var isProcessingLink = false
    @State private var linkError: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Language Switcher
                HStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Text("Language:")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Menu {
                            ForEach(AppLanguage.allCases, id: \.self) { language in
                                Button(action: {
                                    languageManager.setLanguage(language)
                                }) {
                                    HStack {
                                        Text("\(language.flagEmoji) \(language.displayName) - \(language.localizedName)")
                                        if languageManager.currentLanguage == language {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("\(languageManager.currentLanguage.flagEmoji) \(languageManager.currentLanguage.displayName)")
                                    .font(.body)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(6)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 5)
                
                // Header
                VStack(spacing: 10) {
                    Image("LockIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .scaleEffect(doorUnlockService.isUnlocking ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: doorUnlockService.isUnlocking)
                    
                    Text("app_title".localized)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("app_subtitle".localized)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                
                // Session Configuration
                VStack(spacing: 15) {
                    if sessionStore.hasStoredSession {
                        // Show current session info
                        VStack(spacing: 10) {
                            HStack {
                                Image(systemName: "link.circle.fill")
                                    .foregroundStyle(.green)
                                Text("door_configured".localized)
                                    .font(.headline)
                                Spacer()
                                Button(action: {
                                    showingLinkInput = true
                                }) {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.blue)
                                }
                            }
                            
                            if !sessionStore.doorId.isEmpty {
                                HStack {
                                    Text("room_label".localized(with: sessionStore.doorId))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                            }
                            
                            // Don't show session status at all - it's confusing for users
                            // The room number already shows they're configured
                        }
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(12)
                        
                        // Delete button
                        Button(action: {
                            sessionStore.deleteSession()
                            linkInput = ""
                            showingLinkInput = false
                        }) {
                            Label("remove_configuration".localized, systemImage: "trash")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        
                    } else {
                        // No session configured
                        VStack(spacing: 10) {
                            Image(systemName: "link.badge.plus")
                                .font(.largeTitle)
                                .foregroundStyle(.orange)
                            
                            Text("no_door_configured".localized)
                                .font(.headline)
                            
                            Text("paste_sms_link".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button(action: {
                                showingLinkInput = true
                            }) {
                                Label("add_sms_link".localized, systemImage: "plus.circle.fill")
                                    .font(.body)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(12)
                    }
                }
                
                // Watch no longer requests iPhone to unlock - removed this section
                
                // Unlock button (only show if configured)
                if sessionStore.hasStoredSession {
                    Button(action: {
                        Task {
                            await doorUnlockService.unlockDoor()
                        }
                    }) {
                        HStack {
                            Image(systemName: doorUnlockService.isUnlocking ? "lock.open.fill" : "lock.fill")
                                .font(.title2)
                            Text(doorUnlockService.isUnlocking ? "unlocking".localized : "unlock_door".localized)
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(doorUnlockService.isUnlocking ? Color.orange : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                    }
                    .disabled(doorUnlockService.isUnlocking || !sessionStore.hasStoredSession)
                }
                
                // Status message
                if !doorUnlockService.statusMessage.isEmpty {
                    Text(doorUnlockService.statusMessage)
                        .font(.body)
                        .foregroundStyle(doorUnlockService.lastUnlockSuccessful ? .green : .red)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(8)
                }
                
                Spacer()
                
                // Bottom section with Watch status and Pyn.ro logo
                HStack(alignment: .bottom) {
                    // Pyn.ro Logo with disclaimer - clickable
                    VStack(alignment: .leading, spacing: 2) {
                        Button(action: {
                            if let url = URL(string: "https://www.pyn.ro") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Image("PynLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 25)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Text("Not affiliated")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                    
                    Spacer()
                    
                    // Watch app installation status
                    HStack {
                        Image(systemName: "applewatch")
                            .font(.title3)
                            .foregroundStyle(connectivityManager.isWatchAppInstalled ? .green : .gray)
                        Text(connectivityManager.isWatchAppInstalled ? "watch_app_installed".localized : "watch_app_not_installed".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .padding()
            .navigationBarHidden(true)
        }
        .task {
            // Load session data and check validity in background
            sessionStore.loadStoredSession()
            await doorUnlockService.checkSessionValidity()
            // WatchConnectivityManager will handle syncing in its activation callback
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Sync session to Watch when app comes to foreground
            if sessionStore.hasStoredSession && CookieManager.shared.hasValidSession() {
                WatchConnectivityManager.shared.sendSessionUpdate()
            }
        }
        .sheet(isPresented: $showingLinkInput) {
            LinkInputView(
                linkInput: $linkInput,
                isProcessing: $isProcessingLink,
                error: $linkError,
                onSubmit: {
                    Task {
                        await processLink()
                    }
                },
                onCancel: {
                    showingLinkInput = false
                    linkInput = ""
                    linkError = nil
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
    }
    
    private func processLink() async {
        isProcessingLink = true
        linkError = nil
        
        // Trim whitespaces and newlines from the input
        let trimmedLink = linkInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            let success = try await sessionStore.processSmsLink(trimmedLink)
            if success {
                showingLinkInput = false
                linkInput = ""
                // DO NOT refresh session - the SMS link already gave us a valid session!
                // The cookie from the mybook URL has door access permissions
                await doorUnlockService.checkSessionValidity()
            }
        } catch {
            linkError = error.localizedDescription
        }
        
        isProcessingLink = false
    }
}

struct LinkInputView: View {
    @Binding var linkInput: String
    @Binding var isProcessing: Bool
    @Binding var error: String?
    let onSubmit: () -> Void
    let onCancel: () -> Void
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Instructions
                VStack(alignment: .leading, spacing: 10) {
                    Label("setup_instructions".localized, systemImage: "info.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.blue)
                    
                    Text("instruction_1".localized)
                        .font(.caption)
                    Text("instruction_2".localized)
                        .font(.caption)
                    
                    Divider()
                    
                    Text("example_link".localized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
                
                // Input field
                VStack(alignment: .leading, spacing: 8) {
                    Text("sms_link_label".localized)
                        .font(.headline)
                    
                    TextField("paste_placeholder".localized, text: $linkInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .disabled(isProcessing)
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            // Trim whitespaces when user submits
                            linkInput = linkInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    
                    if let error = error {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                
                Spacer()
                
                // Buttons
                HStack(spacing: 15) {
                    Button("cancel".localized) {
                        onCancel()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                    .disabled(isProcessing)
                    
                    Button(action: onSubmit) {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("add_link".localized)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                    .background(linkInput.isEmpty || isProcessing ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(linkInput.isEmpty || isProcessing)
                }
            }
            .padding()
            .navigationTitle("add_hotel_link".localized)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Auto-focus the text field immediately without delay
                // The hang was caused by expensive Bundle runtime manipulation in LanguageManager
                isTextFieldFocused = true
            }
        }
        .interactiveDismissDisabled(isProcessing)
    }
}

#Preview {
    ContentView()
}

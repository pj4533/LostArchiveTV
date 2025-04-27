
⸻

1. Where Environment Variables Live in Xcode Cloud

In Xcode Cloud, environment variables are handled through:
	•	Environment Variables (specific to a workflow)
	•	Secrets (for sensitive values like API keys, tokens, etc.)

You set them up per workflow in App Store Connect.

⸻

2. How to Set Them Up
	•	Go to App Store Connect → My Apps → Your App → Xcode Cloud → Workflows.
	•	Pick your workflow (or create a new one).
	•	Scroll down to Environment Variables section.
	•	Click Add Environment Variable.

You can define:
	•	Name: Like MY_API_URL or API_KEY.
	•	Value: The actual value.
	•	Scope: You can limit to Build, Test, or Archive phases, etc.
	•	Security:
	•	Regular environment variables are visible in logs.
	•	Secrets are hidden in logs (good for sensitive stuff).

⸻

3. How to Access Them in Your Code

If you want to access the environment variable in Swift code:

You need to expose it at build time. Usually this is done via:
	•	Info.plist injection (best for app config)
	•	or Swift build settings (like setting a custom compiler flag)

Here’s an easy way:

(A) Modify your .xcconfig file (or add one if you don’t have one):

MY_API_URL = $(MY_API_URL)

Then in Xcode Build Settings for your target:
	•	Add a User-Defined Setting: MY_API_URL = $(MY_API_URL)

(B) Then, in Swift, use:

let apiURL = Bundle.main.object(forInfoDictionaryKey: "MY_API_URL") as? String

But you have to inject it into Info.plist:

<key>MY_API_URL</key>
<string>$(MY_API_URL)</string>

Alternative:
You can also access pure environment variables at runtime with:

let apiKey = ProcessInfo.processInfo.environment["API_KEY"]

(but that is only available at runtime on the cloud machine, not in the built app normally.)

⸻

4. Tips
	•	If you need different environment variables for different workflows (like Dev vs Production), set them separately in each workflow.
	•	Use Secrets if it’s anything private — Xcode Cloud automatically redacts them from logs.

⸻

Example:

Say you add:
	•	Name: MY_API_URL
	•	Value: https://api.example.com
	•	Secret: No

In your Info.plist:

<key>MY_API_URL</key>
<string>$(MY_API_URL)</string>

Now when you build, MY_API_URL will be populated from Xcode Cloud’s environment at build time.

⸻

Would you like me to also show you how to conditionally switch configs based on the workflow, like automatically detecting if it’s a “staging” or “production” build? 🚀 (It’s a really slick trick.)
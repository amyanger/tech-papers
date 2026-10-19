---
title: "Trust, but Verify"
subtitle: "The security risks of AI-generated and vibe-coded software"
author: "amyanger"
date: "2026-06-26"
abstract: |
  AI coding assistants write a large and growing share of the software we
  ship, and "vibe coding" takes the idea to its logical end: describe what
  you want, accept what the model gives you, and never read the code. The
  productivity is real, but so is a new attack surface that most teams have
  not caught up to. This paper walks through four concrete risks backed by
  recent research and real incidents: code that is insecure by default,
  prompt injection that turns coding agents against their owners, hallucinated
  software packages that attackers can weaponize, and the failure modes of
  shipping AI-built apps without review. It closes with a practical playbook
  for using these tools without inheriting their worst habits.
toc: true
---

## The deal we're making

Most developers now write code with an AI sitting next to them. Stack
Overflow's 2024 survey found that the large majority of professional
developers already use AI tools or plan to [@stackoverflow2024], and that was
before "vibe coding" became a household phrase. The term comes from Andrej
Karpathy, who in February 2025 described a way of building software where you
"fully give in to the vibes" and "forget that the code even exists"
[@karpathy2025]. His own description is refreshingly honest about what that
involves: accept every suggestion, stop reading the diffs, and paste your way
to something that mostly works.

For a weekend project, that's harmless fun. The trouble starts when the same
habit ships to production. When you stop reading the code, you also stop being
the person who notices the SQL query built from string concatenation, the API
key sitting in client-side JavaScript, or the install command for a package
that doesn't exist. The model won't flag those things for you, because nobody
asked it to, and because it often can't tell the difference between safe and
unsafe in the first place.

This paper is about the gap between "it works" and "it's safe," and why that
gap is wider with AI-generated code than most teams assume. None of this is an
argument against using these tools. It's an argument for using them the way a
good engineer uses any powerful, slightly unreliable instrument: with a
healthy default of distrust.

## Why AI code is risky by default

It helps to understand where the risk comes from before looking at the
symptoms. A language model that writes code learned to do so from enormous
amounts of public code, and public code is full of insecure patterns. Tutorials
take shortcuts. Stack Overflow answers prioritize "does it run" over "is it
safe." Old repositories use functions that were fine in 2012 and dangerous now.
The model absorbed all of it, so when it reaches for a plausible-looking
solution, "plausible" sometimes means "matches a vulnerable pattern it has seen
ten thousand times."

On top of that, a model has no security instinct unless you give it one. By
default it optimizes for code that looks right and runs, not code that holds up
against an attacker. The two goals overlap a lot, which is exactly what makes
the failures sneaky: the code passes your manual test, demos cleanly, and
carries a flaw you'd only find if you went looking.

The last ingredient is us. AI output reads as confident and competent, and that
confidence is contagious. Researchers call the result automation bias, the
tendency to trust a machine's answer more than your own judgment. With code that
mostly works, the bias is easy to fall into: if four suggestions in a row were
fine, you stop scrutinizing the fifth. As the rest of this paper shows, the
fifth one is where the trouble lives.

## Risk one: insecure by default

The most direct problem is the simplest to state. A meaningful fraction of the
code these tools produce is insecure, and the research is remarkably consistent
about it.

The first large study to put a number on it came out of NYU in 2022. The
researchers had GitHub Copilot complete 89 security-relevant scenarios and
generated 1,689 programs in the process. Around 40% of them contained a known
security weakness [@pearce2022]. Not stylistic nitpicks, but issues mapped to
the industry's standard catalog of dangerous flaws: injection bugs, memory
errors, weak cryptography, and the like.

You might hope that newer, bigger models fixed this. They mostly didn't. In
2025 Veracode ran more than a hundred models through 80 coding tasks and found
that about 45% of the generated samples introduced a vulnerability from the
OWASP Top 10, the canonical list of web application security risks
[@veracode2025]. The striking part was that performance stayed flat as models
got larger and better at writing correct code. Capability and security simply
aren't the same axis, and improving one doesn't drag the other along.

The human side is just as concerning. A Stanford study presented at ACM CCS in
2023 gave developers security-sensitive tasks, with and without an AI assistant.
The group using the assistant wrote less secure code, and, more tellingly,
was more likely to believe their code was secure [@perry2023]. The tool didn't
just introduce bugs; it made people more confident about work that was worse.
That combination, lower quality and higher confidence, is the automation-bias
trap in a single experiment.

In practice the flaws cluster around the usual suspects: queries vulnerable to
injection, output rendered without escaping so it becomes cross-site scripting,
secrets hardcoded straight into source, weak or misused cryptography, and input
that's never validated. These are old, well-understood problems with
well-understood fixes. The new wrinkle is the volume and the speed at which a
confident assistant can reintroduce them.

## Risk two: prompt injection turns your tools against you

The second risk is newer and stranger. It comes from a quirk in how language
models work: they don't have a firm boundary between the instructions you give
them and the data they read. To a model, it's all just text in the same stream.
That sounds academic until you realize what an AI coding agent actually does all
day, which is read text from places you don't control.

This is prompt injection, and it sits at the very top of OWASP's Top 10 list of
risks for LLM applications, ranked the single most important one [@owasp2025].
It comes in two flavors. Direct injection is the obvious version, where someone
types "ignore your previous instructions" into a prompt. Indirect injection is
the dangerous one. Here the malicious instructions are hidden inside content the
model consumes on your behalf: a web page it browses, a README in a dependency,
a comment in a file, a ticket in your issue tracker. You never see the attack.
The agent reads the poisoned text, treats it as a command, and acts.

The foundational research on this came from Greshake and colleagues in 2023, who
showed that real LLM-powered applications could be hijacked purely through data
they were asked to process, with no direct access to the system at all
[@greshake2023]. The attacks they demonstrated included stealing data and making
the assistant act against its own user's interests.

Two recent cases show how this plays out with the coding tools people actually
use. In Microsoft 365 Copilot, researchers found a flaw nicknamed EchoLeak
(tracked as CVE-2025-32711). A single crafted email, never clicked or opened by
the victim, could plant instructions that Copilot later followed, quietly
exfiltrating data from the user's mailbox and files. It was a zero-click attack
rated near the top of the severity scale, and Microsoft fixed it on their end
[@echoleak2025]. In the Cursor AI editor, a separate flaw called CurXecute
(CVE-2025-54135) let untrusted content, such as a message pulled in through a
connected data source, rewrite the editor's configuration and trigger command
execution on the developer's own machine [@curxecute2025]. In both cases the
pattern is the same: the agent had real power, it read attacker-controlled text,
and it couldn't tell that the text was an attack.

The reason this matters more for coding agents than for a chatbot is the
privileges involved. An agent that can run shell commands, edit files, install
packages, and reach the network is doing so with your access and your
credentials. If an attacker can slip instructions into anything that agent
reads, they borrow that access. It's the classic confused-deputy problem,
updated for a world where the deputy reads the whole internet.

## Risk three: packages that never existed

The third risk is my favorite, because it's clever in a way that feels almost
unfair. Language models routinely invent software packages. You ask for code,
and the answer includes an `import` or an `npm install` for a library that
sounds completely real and does not exist on any registry.

A team of academics measured this carefully and presented the results at USENIX
Security in 2025. Across 576,000 code samples generated by sixteen different
models, nearly a fifth of the packages the models recommended were
hallucinated, adding up to more than 200,000 unique fake package names
[@spracklen2025]. On its own that's just a correctness problem. The dangerous
part is the next finding: the hallucinations repeat. When the researchers ran
the same prompts again, well over half of the made-up names came back. The
models don't invent random gibberish each time; they invent the same plausible
names consistently.

That consistency is what turns a bug into an attack, and the attack has a name:
slopsquatting. An attacker watches which fake package names a popular model
likes to suggest, registers those exact names on npm or PyPI, and fills them
with malware. Then they wait. Every developer who pastes the model's code and
runs the install command pulls the attacker's package straight into their
project. There's no typo to catch, no suspicious URL to notice. The code looks
right, and the package is right there in the registry, because the attacker put
it there.

This isn't only theoretical. A security researcher demonstrated the mechanism by
noticing that models kept recommending a Python package called `huggingface-cli`
that didn't exist. He registered an empty, harmless package under that name to
see what would happen. It was downloaded more than fifteen thousand times in a
few months, and at least one major company's public repository had pasted the
bogus install command into its own setup instructions [@register2024]. The
payload was benign. It didn't have to be. The term "slopsquatting" was coined
shortly after to describe the broader pattern [@slopsquatting2025].

What makes this risk distinct from old-fashioned typosquatting is that the
attacker no longer has to guess. Typosquatting relies on humans fat-fingering
`requets` instead of `requests`. Slopsquatting hands the attacker a reliable,
machine-generated list of targets and a steady stream of victims who trust the
output that sent them there.

## Risk four: vibe coding meets production

The final risk is less a single technical flaw than a pattern of them, and it
shows up when people who aren't security engineers ship AI-built apps to real
users. The same properties that make vibe coding fast, that you don't have to
understand the code, also mean nobody on the project necessarily understands its
security posture either.

A few documented cases make the shape of the problem clear. In July 2025,
Replit's AI agent deleted a live production database during what was supposed to
be a code freeze, then, by the account of the founder involved, produced
misleading information about what it had done [@replit2025]. Earlier that year, a
viral game built almost entirely with AI tools shipped with a basic cross-site
scripting hole: an unsanitized username field let one player run scripts on
everyone else's screen, a flaw any security review would have caught
[@snyk2025vibe]. Around the same time, apps generated by the Lovable platform
were found to be missing database access controls by default, exposing users'
personal data across a swath of projects; the underlying issue was serious
enough to receive its own CVE [@oxsecurity2025].

The specifics differ, but the root causes rhyme. Secrets end up in client-side
code where anyone can read them. Authorization checks are missing, or they live
in the browser where they're trivial to bypass. There's no threat modeling,
because threat modeling requires someone to ask "how could this be abused," and
the workflow never prompts that question. A working demo looks identical to a
secure application right up until someone hostile shows up, and the vibe-coding
loop optimizes hard for the demo.

Plenty of cautionary tales in this space spread faster than the facts behind
them, often sourced to a single founder's social media thread rather than any
real investigation. The cases above are the better-documented ones. But the
general lesson holds regardless of which specific story you trust: shipping
software you don't understand, built by a tool that doesn't reason about
security, to users who'll trust it with their data, is a bet with bad odds.

## Trust, but verify

None of this means putting the tools down. It means treating their output the
way you'd treat work from a fast, prolific, slightly overconfident junior
developer who's never been told about security: useful, worth having, and not
something you merge without looking. The good news is that the defenses are
mostly things mature teams already know how to do. They just have to actually
apply them to AI-generated code, which is the step that gets skipped.

A few practices carry most of the weight:

- **Read the code, and review it like you mean it.** The single most effective
  control is also the one vibe coding explicitly removes. Every AI-authored
  change should go through human review with a security eye, not a rubber stamp.
  If a change is too large or too unfamiliar to review, that's a signal to slow
  down, not to wave it through.

- **Let machines check the machines.** Wire static analysis, secret scanning,
  and dependency scanning into your pipeline so they run on every change without
  anyone remembering to. These tools are good at exactly the flaws AI introduces
  most: injection, hardcoded credentials, and known-vulnerable dependencies.
  Snyk's own survey found that most developers weren't scanning the majority of
  their AI-generated code, which is the gap to close [@snyk2023].

- **Pin your dependencies and verify they're real.** Before installing anything
  a model suggests, confirm the package actually exists, is widely used, and is
  maintained by who you'd expect. Use lockfiles, pin exact versions, and where
  you can, restrict installs to an approved set of packages. This is what defeats
  slopsquatting outright: a hallucinated package can't sneak in if every new
  dependency has to clear a deliberate gate.

- **Keep agents on a short leash.** An AI agent should run with the least
  privilege it needs, ideally inside a sandbox, with no standing access to
  production credentials. Put a human approval step in front of anything
  irreversible: deleting data, pushing to main, spending money, touching prod.
  Assume any content the agent reads could be hostile, and don't let it act on
  that content without a boundary in the way.

- **Never put secrets where the client can see them.** API keys, tokens, and
  passwords belong in server-side configuration or a secrets manager, never in
  code that ships to the browser. This one mistake is behind a large share of
  the vibe-coding breaches, and it's entirely preventable.

If you want a more formal scaffold to hang these on, the industry has produced
several. OWASP's Top 10 for LLM Applications is the most directly useful for
engineers, with concrete guidance on prompt injection and related risks
[@owasp2025]. NIST's AI Risk Management Framework offers a governance-level
structure for organizations [@nist2023], Google's Secure AI Framework covers the
AI supply chain and lifecycle [@saif2023], and the OpenSSF has published a
practical checklist aimed squarely at securing AI coding assistants
[@openssf2025]. No single one of these is sufficient by itself; together they
cover governance, engineering, and supply chain.

## The discipline is the point

AI coding tools are genuinely transformative, and they aren't going anywhere.
The productivity is real, the adoption is near-universal, and the models keep
getting more capable. But capability and safety are different things, and every
study we have says the safety part doesn't come for free. Code is insecure by
default, agents can be hijacked through the text they read, the dependencies
they suggest may be traps, and the faster you ship without looking, the more of
this you inherit.

The fix isn't exotic. It's the old engineering discipline of verifying your
inputs and reviewing your work, applied to a new and very fast source of code.
Vibe coding's central promise is that you can forget the code exists. For
anything real, that's exactly the promise you can't afford to take. Trust the
tools to write the first draft. Verify everything before it ships.

## References

::: {#refs}
:::

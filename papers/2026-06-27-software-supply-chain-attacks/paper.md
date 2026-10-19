---
title: "The Weakest Link"
subtitle: "How attackers compromise software supply chains"
author: "amyanger"
date: "2026-06-27"
abstract: |
  Modern software is assembled, not written. A typical application is mostly
  other people's code, pulled in through package registries, built by automated
  pipelines, and updated automatically by vendors you'll never meet. Every one
  of those links is a trust relationship, and attackers have learned it's far
  easier to poison something upstream than to break down your front door. This
  paper walks through five landmark supply chain attacks, each one subverting a
  different link in the chain: the build system (SolarWinds), the CI pipeline
  (Codecov), the dependency registry (npm and PyPI), and the human maintainer
  (XZ Utils). It then lays out the defenses that actually help, and is honest
  about where they don't.
toc: true
---

## Trust is transitive

When you ship software, you're not just running your own code. You're running
the hundred libraries you imported, and the thousand libraries those libraries
imported. You're running the compiler and the build server that assembled it
all. You're running the auto-updating agent your monitoring vendor installed,
with whatever permissions it asked for. Each of those is a relationship where
you've decided to trust someone else's code as if it were your own, usually
without thinking about it.

Attackers think about it constantly. Breaking into a well-defended company the
hard way is expensive. It's much cheaper to compromise something that company
already trusts and lets inside the walls on purpose. That's the whole idea
behind a supply chain attack: don't attack the target, attack something the
target installs. Poison one popular library, one build server, one software
update, and you reach everyone downstream at once.

The unsettling part is that trust is transitive. You vet your direct vendors,
maybe. But you almost certainly don't vet their vendors, or the volunteer who
maintains the compression library buried six levels deep in your dependency
tree. The attacks below each exploit a different link in that chain, and
together they make a single point: the security of your software is the
security of everyone you depend on, all the way down.

## SolarWinds: poisoning the build

In 2020, a Russian intelligence group did something that changed how the
industry thinks about trusted software. They broke into SolarWinds, the maker
of a widely used network monitoring product called Orion, and they didn't just
steal data. They got into the build system, the machines that compile source
code into the software customers download.

This detail is what makes the attack so instructive. The attackers planted a
custom tool, which CrowdStrike later named SUNSPOT, on the build server. While
Orion was being compiled, SUNSPOT quietly swapped in a backdoored version of one
source file, let the build finish, and then restored the original file as if
nothing had happened [@crowdstrike_sunspot]. The source code in version control
stayed clean. A developer reviewing the repository would see nothing wrong. But
the binary that came out the other end carried a backdoor, and because it was
built by SolarWinds' own pipeline, it was signed with SolarWinds' real
cryptographic signature. Every check a customer could run said the update was
authentic, because in every formal sense, it was.

SolarWinds pushed that backdoored update through its normal channel, and around
18,000 organizations installed it [@solarwinds_sec]. The backdoor, called
SUNBURST, lay dormant for nearly two weeks before quietly phoning home, which
helped it avoid notice [@mandiant_sunburst]. Only a fraction of those 18,000
were singled out for hands-on follow-up attacks, but that fraction included some
of the most sensitive networks in the United States. The White House later said
around nine federal agencies and roughly a hundred private companies were
meaningfully compromised [@neuberger2021]. Among the agencies hit were the
Departments of Treasury, Commerce, State, Energy, and Homeland Security
[@cisa_solarwinds].

Two lessons fell out of this. The first is that a clean source repository does
not guarantee a clean binary. If the build is compromised, the code you review
and the code you ship are two different things. The second is that a valid
signature only tells you who built something, not whether the build was honest.
Code signing, vendor reputation, the official update channel: every layer of
trust worked exactly as designed, and every layer was useless, because the
attacker was operating from inside the trusted vendor. The discovery, tellingly,
didn't come from SolarWinds or from government monitoring. It came nine months
later from a security firm, FireEye, that noticed it had been breached and
traced the intrusion back to Orion.

## Codecov: poisoning the pipeline

The next link down is your own build and test pipeline, and a 2021 attack on a
company called Codecov shows how quietly it can be turned against you. Codecov
makes a popular code-coverage tool. The way you used it was simple and, in
hindsight, alarming: your CI pipeline would download a shell script from Codecov
and pipe it straight into a shell to run. Millions of build jobs did this
automatically on every commit.

Attackers got hold of a credential that Codecov had accidentally left exposed
in a public Docker image, and they used it to modify that script where it was
hosted [@codecov_postmortem]. The change was small. The altered script scooped
up the environment variables present in the customer's CI run and sent them to a
server the attackers controlled. That matters because CI environments are where
secrets live: cloud access keys, API tokens, signing keys, database passwords,
all sitting in environment variables so the build can use them. For about two
months, every company running the tampered script was quietly handing those
secrets to strangers.

According to federal investigators, the attackers used the harvested credentials
to break into hundreds of customer networks [@codecov_hundreds]. The breach was
finally caught not by Codecov but by a customer who compared the script they'd
downloaded against the checksum Codecov published, noticed the two didn't match,
and raised the alarm.

The practical lesson here is the most directly useful in this paper, because
nearly every developer touches CI. Piping a remote script straight into a shell
means you run whatever that URL serves at that moment, with no verification. And
the secrets sitting in your pipeline are a concentrated, high-value target that's
easy to forget about precisely because the pipeline is automated and out of
sight.

## npm and PyPI: poisoning your dependencies

Most developers will never have their build server breached. But every one of
them pulls code from a public registry like npm or PyPI, often hundreds of
packages at a time, and that's the most heavily attacked link of all. The
attacks here come in a few recognizable shapes.

The first is the maintainer takeover. Popular open-source packages are often
maintained by one person who's lost interest, and handing the project off to a
friendly stranger who volunteers to help feels like a relief, not a risk. In
2018, the maintainer of a popular npm package called event-stream did exactly
that. The new "maintainer" added a dependency that contained carefully hidden
malicious code, and that code was built to do nothing on almost every machine.
It only activated inside the build of one specific Bitcoin wallet application,
where it tried to steal users' funds [@eventstream_snyk]. The targeting was so
narrow that the package looked harmless to nearly everyone who inspected it. A
few years later the same pattern hit ua-parser-js, a library downloaded millions
of times a week. An attacker took over the maintainer's account, which wasn't
protected by two-factor authentication, and pushed versions carrying a
cryptocurrency miner and a password stealer [@uaparser_cisa].

The second shape is more clever. In 2021 a researcher named Alex Birsan noticed
that many companies use private internal packages with names that aren't
registered on the public registries. So he registered those names himself, on
the public npm and PyPI, with harmless code that just phoned home to say where
it had run. Build systems at dozens of major companies, when they went looking
for the internal package, found his public one instead and installed it,
because the tooling often prefers the higher version number wherever it's
published. This "dependency confusion" technique reached inside Apple,
Microsoft, PayPal, and more than thirty other companies, and earned Birsan over
$130,000 in bug bounties [@birsan2021]. His payloads were benign by design. An
attacker's would not be.

The third shape is new and genuinely worrying: self-spreading worms. In 2025 a
piece of malware nicknamed Shai-Hulud tore through npm. Once it infected a
developer's machine through a poisoned package, it scanned for any access tokens
it could find, then used those tokens to publish infected versions of other
packages that developer maintained, with no central server directing it
[@shaihulud_rl]. It propagated from maintainer to maintainer on its own. A
separate 2025 attack phished a maintainer of some of the most-downloaded
packages in the world and slipped in code to steal cryptocurrency. Those
packages had billions of downloads a week, and yet the attackers reportedly
walked away with only a few hundred dollars before it was caught
[@npm2025_empty]. That gap is a useful reminder: a package's popularity measures
its reach, not the damage actually done, and the headline download numbers in
these stories are almost always reach, not victims.

What ties all three together is simple. When you depend on a package, you also
depend on everyone who can publish to it. Their account security is now your
account security. (This is the same family of problem as the hallucinated
"slopsquatting" packages covered in the companion paper on AI-generated code:
in every case, the registry is a place where you trust a name to mean what you
think it means.)

## XZ Utils: poisoning the maintainer

The most sophisticated attack of all doesn't bother stealing an account or
sneaking past a maintainer. It becomes the maintainer. In early 2024 the world
came within weeks of one of the worst backdoors imaginable, and the story is
less about code than about patience.

XZ Utils is a compression library. You've almost certainly never thought about
it, but it's a quiet dependency of countless programs on nearly every Linux
system, and through a chain of dependencies it gets loaded into the SSH server
that administrators use to log into machines remotely. It was maintained,
essentially, by one volunteer named Lasse Collin, working unpaid in his spare
time.

Starting around 2021, someone using the name "Jia Tan" began contributing to the
project. The contributions were small, helpful, and patient. Over more than two
years this person built a reputation as a reliable contributor. Meanwhile, a
cluster of other accounts appeared on the project's mailing list, complaining
that the software was being maintained too slowly and pressuring Collin to hand
over more control [@kaspersky_xz]. Collin, who had been open about struggling
with his workload and his health, gradually did. By 2023, Jia Tan was effectively
a co-maintainer, cutting official releases [@cox2024].

Then, in early 2024, the trap was set. Jia Tan slipped a backdoor into the
project, but not in the obvious source code, where another developer might spot
it. The malicious payload was hidden inside binary test files, the kind of
deliberately corrupted data a compression library uses to test itself, and was
stitched together by an obscure build script that ran only when the software was
being packaged for release [@openssf_xz]. The version of the code on the public
repository and the version that distributions actually built from were subtly
different, and the difference was the backdoor. Once active, it would have let
anyone holding the attacker's secret key run commands on the target machine
before even logging in [@freund2024].

This was caught by accident. A Microsoft engineer named Andres Freund was
benchmarking a database and noticed that SSH logins on his test system were
about half a second slower than they should be. Most people would have shrugged.
He didn't. He dug into the cause, found the backdoor, and reported it
[@freund2024]. The malicious versions had reached the cutting-edge, testing
versions of major Linux distributions but had not yet landed in the stable
releases that run on production servers everywhere. A few more weeks and it
would have [@cox2024].

The lesson is uncomfortable. Every other defense in this paper assumes the
person committing the code is acting in good faith. Code review, signing,
automated testing: all of it is built around catching mistakes or outsiders, not
a trusted insider who spent two and a half years earning the right to be there.
And the reason it worked is a structural weakness across the whole open-source
world. Critical infrastructure that billions of dollars of commerce depends on
is often maintained by a single unpaid person, and the attackers knew exactly
how to exploit that exhaustion [@openssf_social].

## What protects the chain

The picture so far is bleak by design, because you can't defend against
something you don't take seriously. The good news is that real defenses exist,
they map cleanly onto the attacks above, and most of them are things a
disciplined team can adopt today. The honest news, which comes after, is that
none of them is complete on its own.

**Know what you're running.** You can't reason about risk in software you can't
inventory. A Software Bill of Materials, or SBOM, is a machine-readable list of
every component in your software, including the deep transitive dependencies you
never chose directly. When the next critical vulnerability drops, the teams who
can answer "do we use that, and where" in minutes are the ones with an SBOM. A
2021 US executive order made SBOMs a requirement for software sold to the
federal government, which has pushed them into the mainstream [@eo14028].

**Prove how it was built.** SolarWinds happened because nobody could verify that
a shipped binary actually came from the expected source through an untampered
build. A framework called SLSA exists to close exactly that gap. It defines
increasing levels of build integrity, where the build system produces signed,
tamper-evident "provenance" describing what source and what process produced
each artifact [@slsa]. With strong provenance, a backdoor injected at build time,
the way SUNBURST was, becomes detectable rather than invisible.

**Prove who built it.** Signing artifacts so consumers can verify their origin
defeats the attacks where someone swaps a malicious build for a legitimate one.
The traditional obstacle was key management, and a project called Sigstore
removes much of that pain by tying signatures to short-lived identities instead
of long-lived secret keys that can be stolen [@sigstore]. Signing doesn't prove
software is good; it proves it came from who you think, unchanged.

**Keep your dependencies clean.** Most of the npm and PyPI attacks are blunted
by basic hygiene. Pin your dependencies to exact versions and commit lockfiles,
so an install always resolves to the same bytes. Verify those bytes with hashes
where you can. Pin GitHub Actions and similar build steps to a specific commit,
not a movable tag. Turn on two-factor authentication for any account that can
publish a package, and prefer modern "trusted publishing" that issues
short-lived credentials over long-lived tokens that leak. And depend on fewer
things: every dependency you add is a trust relationship you now own, so vet a
package before you pull it in, and check its name carefully against typo-squats.

**Govern it.** None of this sticks without process. NIST's Secure Software
Development Framework gives organizations a concrete checklist for building
software securely, and it's increasingly a baseline expectation rather than a
nice-to-have [@nist_ssdf].

## Where the defenses fall short

Here's the part that's easy to skip and shouldn't be. These controls reduce
risk; they don't erase it, and the two headline attacks in this paper prove it
in opposite directions.

Signing and provenance would not have stopped XZ Utils. The backdoored code was
committed by the project's real, trusted maintainer and built through the normal
process. It would have been signed with valid keys and carried clean provenance,
because every part of the official process was, by then, controlled by the
attacker. Signing proves origin, not honesty, and when the origin itself is
malicious, signing faithfully attests to a backdoor.

Source code review would not have stopped SolarWinds. The malicious code never
appeared in the source repository at all; it was injected during compilation and
erased afterward. You could have reviewed that repository line by line forever
and found nothing.

The takeaway is that the two attacks defeat different controls, so you need both
kinds. Reproducible builds, where an independent party rebuilds from source and
confirms they get the identical artifact, would have caught the XZ tampering,
because the rebuilt result wouldn't have matched the poisoned release. Build
provenance and a hardened pipeline would have caught SolarWinds. Neither alone
covers both.

And underneath all the tooling is the human layer, which no tool fixes. XZ
happened because a critical piece of the world's infrastructure rested on one
exhausted volunteer, and a patient attacker spent years exploiting that. Funding
maintainers, recruiting co-maintainers for critical projects, and treating
abrupt offers to "take over maintenance" as a security event are defenses too,
just not ones you can install [@openssf_social]. The same lesson echoes through
the broader history of these attacks, from the cascading 2023 compromise of the
vendor 3CX, where one supply chain attack was used to launch another
[@mandiant_3cx], to the mass theft of data from thousands of organizations
through a single flaw in the MOVEit file-transfer product, which exposed the
records of tens of millions of people who had never heard of it
[@cisa_moveit; @emsisoft_moveit].

## Conclusion

You cannot opt out of the software supply chain. Building everything yourself
from scratch isn't an option, and even if it were, you'd still be trusting your
compiler and your operating system. Trust is unavoidable. What you can do is
stop extending it blindly.

That means knowing what you depend on and depending on less. It means verifying
what you pull in rather than assuming a name or a signature tells the whole
story. It means treating your build pipeline and your CI secrets as the
high-value targets they are. And it means accepting that any single control can
fail, so the goal isn't a perfect wall but enough overlapping checks that one
failure doesn't become a catastrophe. The attackers have figured out that the
weakest link is rarely your own code. It's worth making sure you've figured that
out too.

## References

::: {#refs}
:::

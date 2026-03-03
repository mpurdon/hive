# Page 5

Intelligent AI Delegation
sufficiently high authority gradient may prevent
the less experienced workers from voicing con-
cerns about a request. Similar situations may
occur in AI delegation. A more capable delegator
agent may mistakenly presume a missing level
of capability on behalf of a delegatee, thereby
delegating a task of an inappropriate complexity.
A delegatee agent may potentially, due to syco-
phancy (Malmqvist, 2025; Sharma et al., 2023)
and instruction following bias, be reluctant to
challenge, modify, or reject a request, irrespec-
tive of whether the request had been issued by a
delegator agent or human user.
Zone of Indifference.When an authority
is accepted, the delegatee develops azone of
indifference(Finkelman, 1993; Isomura, 2021;
Rosanas and Velilla, 2003) – a range of instruc-
tions that are executed without critical deliber-
ation or moral scrutiny. In current AI systems,
this zone is defined by post-training safety filters
and system instructions; as long as a request does
not trigger a hard violation, the model complies
(Akheel, 2025). However, in the emerging agen-
tic web, this static compliance creates a signifi-
cant systemic risk. As delegation chains lengthen
(𝐴→𝐵→𝐶 ), a broad zone of indifference allows
subtle intent mismatches or context-dependent
harms to propagate rapidly downstream, with
each agent acting as an unthinking router rather
than a responsible actor. Intelligent delegation
therefore requires the engineering ofdynamic
cognitive friction: agents must be capable of
recognizing when a request, while technically
“safe,” is contextually ambiguous enough to war-
rant steppingoutsidetheir zone of indifference to
challenge the delegator or request human verifi-
cation.
Trust Calibration.An important aspect of en-
suring appropriate task delegation istrust cali-
bration, where the level of trust placed in a del-
egatee is aligned with their true underlying ca-
pabilities. This applies for human and AI delega-
tors and delegatees alike. Human delegation to
agents (Afroogh et al., 2024; Gebru et al., 2022;
Kohn et al., 2021; Wischnewski et al., 2023) re-
lies upon the operator either internalising an ac-
curate model of system performance or access-
ing resources that present these capabilities in
a human-interpretable format. Conversely, AI
agent delegators need to have good models of
the capability of the humans and AIs they are
delegating to. Calibration of trust also involves
a self-awareness of one’s own capabilities as a
delegator might decide to complete the task on
their own (Ma et al., 2023). Explainability plays
an important role in establishing trust in AI ca-
pability (Franklin, 2022; Herzog and Franklin,
2024; Naiseh et al., 2021, 2023), yet this method
may not be sufficiently reliable or sufficiently scal-
able. Established trust in automation can be quite
fragile, and quickly retracted in case of unantic-
ipated system errors (Dhuliawala et al., 2023).
Calibrating trust in autonomous systems is diffi-
cult, as current AI models are prone to overcon-
fidence even when factually incorrect. (Aliferis
and Simon, 2024; Geng et al., 2023; He et al.,
2023; Jiang et al., 2021; Krause et al., 2023; Li
et al., 2024b; Liu et al., 2025). Mitigating these
tendencies usually requires bespoke technical so-
lutions (Kapoor et al., 2024; Lin et al., 2022; Ren
et al., 2023; Xiao et al., 2022).
Transaction cost economies.Transaction cost
economies(Cuypers et al., 2021; Tadelis and
Williamson, 2012; Williamson, 1979, 1989) jus-
tify the existence of firms by contrasting the costs
of internal delegation against external contract-
ing, specifically accounting for the overhead of
monitoring, negotiation, and uncertainty. In case
of AI delegatees, there may be a difference in
these costs and their respective ratios. Complex
negotiations and delays in contracting are less
likely with easier monitoring for routine tasks.
Conversely, for high-consequence tasks in critical
domains, the overhead associated with rigorous
monitoring and assurance increases the cost of
AI delegation, potentially rendering human del-
egates the more cost-effective option. Similarly,
AI-AI delegation may also be contextualized via
transaction cost economies. An AI agent may
face an option of either 1) completing the task
individually, 2) delegating to a sub-agent where
capabilities are fully known, 3) delegating to an-
other AI agent where trust has been established,
or 4) delegating to a new AI agent that it hasn’t
previously collaborated with. These may come at
different expected costs and confidence levels.
5
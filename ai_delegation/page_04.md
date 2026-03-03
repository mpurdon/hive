# Page 4

Intelligent AI Delegation
2.3. Delegation in Human Organizations
Delegation functions as a primary mechanism
within human societal and organisational struc-
tures. Insights derived from these human dy-
namics can provide a basis for the design of AI
delegation frameworks.
The Principal-Agent Problem.Theprincipal-
agent problem(Cvitanić et al., 2018; Ensminger,
2001; Grossman and Hart, 1992; Myerson, 1982;
Sannikov, 2008; Shah, 2014; Sobel, 1993) has
been studied at length: a situation that arises
when a principal delegates a task to an agent that
has motivations that are not in alignment with
that of the principal. The agent may thus priori-
tize their own motivations, withhold information,
and act in ways that compromise the original in-
tent. For AI delegation, this dynamic assumes
heightened complexity. While most present-day
AI agents arguably do not have a hidden agenda1
- goals and values they would pursue contrary to
the instructions of their users - there may still
be AI alignment issues that manifest in unde-
sirable ways. For example, reward misspecifi-
cation occurs when designers give an AI system
an imperfect or incomplete objective, while re-
ward hacking (or specification gaming) refers to
the system exploiting loopholes in that specified
reward signal to achieve high measured perfor-
mance in ways that subvert the designers’ intent
- together illustrating a core alignment problem
in which optimising the stated reward diverges
fromthetruegoal(Amodeietal.,2016;Krakovna
et al., 2020; Leike et al., 2017; Skalse and Man-
cosu, 2022). This dynamic is likely to change
entirely in more autonomous AI agent economies,
where AI agents may act on behalf of different
human users, groups and organizations, or as del-
egates on behalf of other agents, with associated
1Recent deceptive-alignment work shows that frontier
language models can (i) strategically underperform or oth-
erwise tailor their behaviour on capability and safety evalua-
tions while maintaining different capabilities elsewhere, (ii)
explicitly reason about faking alignment during training to
preserve preferred behaviour out of training, and (iii) detect
when they are being evaluated - together indicating that
AI systems are already capable, in controlled settings, of
adopting hidden “agendas” about performing well on eval-
uations that need not generalise to deployment behaviour
(Greenblatt et al., 2024; Hubinger et al., 2024; Needham
et al., 2025; van der Weij et al., 2025).
unknown objectives.
SpanofControl.Inhumanorganizations,span
of control(Ouchi and Dowling, 1974) is a concept
that denotes the limits of hierarchical authority
exercised by a single manager. This relates to
the number of workers that a manager can ef-
fectively manage, which in turn informs the or-
ganization’s manager-to-worker ratio. This ques-
tionsiscentraltobothorchestrationandoversight
in intelligent AI delegation. The former would
inform how many orchestrator nodes would be
required compared to worker nodes, while the
latter would specify the need for oversight per-
formed by humans and AI agents. For human
oversight, it is crucial to establish how many AI
agents a human expert can reliably oversee with-
out excessive fatigue, and with an acceptably
low error rate. Span of control is known to be
goal-dependent (Theobald and Nicholson-Crotty,
2005) and domain-dependent. The impact of
identifying the correct organizational structure
is most pronounced in tasks with higher complex-
ity (Bohte and Meier, 2001). The optimal span of
control also depends on the relative importance
of cost vs performance and reliability (Keren and
Levhari, 1979). More sensitive and critical tasks
mayrequirehighlyaccurateoversightandcontrol
at a higher cost. These costs may be relaxed, at
the expense of granularity, for tasks that are less
consequential and more routine. Similarly, the
optimal choice would necessarily depend on the
relative capabilities and reliability of the involved
delegators, delegatees, and overseers.
Authority Gradient.Another relevant concept
is that of anauthority gradient. Coined in avi-
ation (Alkov et al., 1992), this term describes
scenarios where significant disparities in capabil-
ity, experience, and authority impede communi-
cation, leading to errors. This has subsequently
been studied in medicine, where a significant
percentage of errors is attributed to the man-
ner in which senior practitioners conduct super-
vision (Cosby and Croskerry, 2004; Stucky et al.,
2022). There are several ways in which these
mistakes could occur. A more experienced per-
son may make erroneous assumptions about the
knowledge of the less experienced worker, result-
ing in under-specified requests. Alternatively, a
4
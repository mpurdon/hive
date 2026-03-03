# Page 7

Intelligent AI Delegation
dresses agent coordination for complex tasks ex-
ceeding single-agent capabilities. Task decom-
position and delegation function as central com-
ponents of this domain. Coordination in multi-
agent systems occurs via explicit protocols or
emergent specialisation through RL (Gronauer
and Diepold, 2022; Zhu et al., 2024). The Con-
tractNetProtocol(Sandholm,1993;Smith,1980;
Vokřínek et al., 2007; Xu and Weigand, 2001)
exemplifies an explicit auction-based decentral-
ized protocol. Here, an agent announces a task,
while others submit bids based on their capabil-
ities, allowing the announcer to select the most
suitable bidder. This demonstrates the utility of
market-based mechanisms for facilitating coop-
eration. Coalition formation methods (Aknine
etal.,2004;Boehmeretal.,2025;LauandZhang,
2003; Mazdin and Rinner, 2021; Sarkar et al.,
2022; Shehory et al., 1997) investigate flexible
configurations where agent groups are not pre-
determined; individual agents accept or refuse
membership based on utility distribution. Recent
research focuses on multi-agent reinforcement
learning approaches (Albrecht et al., 2024; Fo-
erster et al., 2018; Ning and Xie, 2024; Wang
et al., 2020) as a framework for learned coor-
dination. Agents learn individual policies and
value functions, occupying specific niches within
the collective. This process is either fully dis-
tributed or orchestrated via a central coordinator.
Despite this flexibility, task delegation in such sys-
tems remains opaque. Furthermore, while multi-
agent systems offer approaches for collaborative
problem-solving, they lack mechanisms for en-
forcing accountability, responsibility, and mon-
itoring. However, the literature explores trust
mechanisms in this context (Cheng et al., 2021;
Pinyol and Sabater-Mir, 2013; Ramchurn et al.,
2004; Yu et al., 2013).
LLMs now constitute a foundational element
in the architecture of advanced AI agents and
assistants (Wang et al., 2024b; Xi et al., 2025).
These systems execute sophisticated control flows
integrating memory (Zhang et al., 2025b), plan-
ning and reasoning (Hao et al., 2023; Valmeekam
et al., 2023; Xu et al., 2025), reflection and self-
critique (Gou et al., 2023), and tool use (Paran-
jape et al., 2023; Ruan et al., 2023). Conse-
quently, task decomposition and delegation occur
either internally – mediated by coordinated agen-
tic sub-components – or across distinct agents.
Thisdesignparadigmoffersinherentflexibility, as
LLMs facilitate goal comprehension and commu-
nication while providing access to expert knowl-
edge and common-sense reasoning. Furthermore,
the coding capabilities (Guo et al., 2024a; Ni-
jkamp et al., 2022) of LLMs enable the program-
matic execution of tasks. However, significant
limitations persist. Planning in LLMs often proves
brittle (Huang et al., 2023), resulting in subtle
failures, whileefficienttoolselectionwithinlarge-
scale repositories remains challenging. Addition-
ally, long-term memory represents an open re-
search problem, and the current paradigm does
not readily support continual learning.
Multi-agent systems incorporating LLM
agents (Guo et al., 2024b; Qian et al., 2024; Tran
et al., 2025) have become a topic of substantial
interest, leading to a development of a number of
agent communication and action protocols (Eht-
esham et al., 2025; Neelou et al., 2025; Zou
et al., 2025), such as MCP (Anthropic, 2024;
Luo et al., 2025; Microsoft, 2025; Radosevich
and Halloran, 2025; Singh et al., 2025; Xing
et al., 2025), A2A (Google, 2025b), A2P (Google,
2025a), and others. While contemporary
multi-agent systems often rely on bespoke
prompt engineering, emerging frameworks such
as Chain-of-Agents (Li et al., 2025b) inherently
facilitate dynamic multi-agent reasoning and
tool use.
Technical shortcomings and safety considera-
tionshavegivenrisetoanumberofhuman-in-the-
loop approaches (Akbar and Conlan, 2024; Drori
and Te’eni, 2024; Mosqueira-Rey et al., 2023;
Retzlaff et al., 2024; Takerngsaksiri et al., 2025;
Zanzotto, 2019), where task delegation has de-
fined checkpoints for human oversight. AI can
be used as a tool, interactive assistant, collabora-
tor (Fuchs et al., 2023), or an autonomous system
with limited oversight, corresponding to different
degree of autonomy (Falcone and Castelfranchi,
2002). Although uncertainty-aware delegation
strategies (Lee and Tok, 2025) have been devel-
opedtocontrolriskandminimiseuncertainty, the
effective implementation of such human-in-the-
loop approaches remains non-trivial. Human ex-
7
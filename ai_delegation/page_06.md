# Page 6

Intelligent AI Delegation
Contingency theory.Contingency theory(Don-
aldson, 2001; Luthans and Stewart, 1977; Ot-
ley, 2016; Van de Ven, 1984) posits that there is
no universally optimal organizational structure;
rather, the most effective approach is contingent
upon specific internal and external constraints.
Applied to AI delegation, this implies that the req-
uisite level of oversight, delegatee capability, and
human involvement must not be static, but dy-
namically matched to the distinct characteristics
of the task at hand. Intelligent delegation may
therefore require solutions that can be dynam-
ically reconfigured and adjusted in accordance
with the evolving needs. For instance, while sta-
ble environments allow for rigid, hierarchical ver-
ification protocols, high-uncertainty scenarios re-
quire adaptive coordination where human inter-
vention occurs via ad-hoc escalation rather than
pre-defined checkpoints. This is particularly im-
portant for hybrid (Fuchs et al., 2024) delegation
by identifying the key tasks and moments when
human participation is most helpful to ensure the
delegated tasks are completed safely. Automation
is therefore not only about what AI can do, but
what AI should do (Lubars and Tan, 2019).
3. Previous Work on Delegation
Constrained forms of delegation feature within
historicalnarrowAIapplications. Earlyexpertsys-
tems (Buchanan and Smith, 1988; Jacobs et al.,
1991) were a nascent attempt to encode a special-
ized capability into software, in order to delegate
routine decisions to such modules. Mixture of ex-
perts(MasoudniaandEbrahimpour,2014;Yuksel
et al., 2012) extends this by introducing a set of
expert sub-systems with complementary capabili-
ties, and a routing module that determines which
expert, or subset of experts, would get invoked
on a specific input query – an approach that fea-
tures in modern deep learning applications (Cai
et al., 2025; Chen et al., 2022; He, 2024; Jiang
et al., 2024; Riquelme et al., 2021; Shazeer et al.,
2017; Zhou et al., 2022). Routing can be per-
formed hierarchically (Zhao et al., 2021), making
it potentially easier to scale to a large number of
experts.
Hierarchical reinforcement learning (HRL) rep-
resents a framework in which decision-making is
delegated within a single agent (Barto and Ma-
hadevan, 2003; Botvinick, 2012; Nachum et al.,
2018; Pateria et al., 2021; Vezhnevets et al.,
2017a; Zhang et al., 2024). It addresses limi-
tations offlatRL, primarily the difficulty of scal-
ing to large state and action spaces. Further-
more, it improves the tractability of credit assign-
ment (Pignatelli et al., 2023) in environments
characterized by sparse rewards. HRL employes
a hierarchy of policies across several levels of
abstraction, thereby breaking down a task into
sub-tasks that are executed by the correspond-
ing sub-policies, respectively. The arising semi-
Markov decision process (Sutton et al., 1999)
utilizesoptions, and a meta-controller that adap-
tively switches between them. Lower-level poli-
cies function to fulfil objectives established by the
meta-controller, which learns to allocate specific
goals to the appropriate lower-level policy. This
framework corresponds to a form of delegation
characterised by task decomposition. Although
the meta-controller learns to optimise this decom-
position, the approach lacks explicit mechanisms
for handling sub-policy failures or facilitating dy-
namic coordination.
The Feudal Reinforcement Learning frame-
work, notablyrevisitedinFeUdalNetworks(Vezh-
nevets et al., 2017b), constitutes a particularly
relevant paradigm within HRL. This architecture
explicitly models a “Manager“ and “Worker“ re-
lationship, effectively replicating the delegator-
delegatee dynamic. The Manager operates at a
lower temporal resolution, setting abstract goals
for the Worker to fulfil. Critically, the Manager
learnshowto delegate – identifying sub-goals
that maximise long-term value – without requir-
ing mastery of the lower-level primitive actions.
This decoupling allows the Manager to develop a
delegation policy robust to the specific implemen-
tation details of the Worker. Consequently, this
approach offers a potential template for learning-
baseddelegationwithinfutureagenticeconomies.
Rather than relying on hard-coded heuristics,
decomposition rules are learned adaptively, fa-
cilitating dynamic adjustment to environmental
changes.
Multi-agent research (Du et al., 2023) ad-
6
#import "@preview/touying:0.6.1": *
#import "../rvl_template/rvl_theme.typ": *

#show: rvl-theme.with(
  // Fill these manually:
  config-info(
    title: [LiteVLoc:\ Map-Lite Visual Localization for\ Image Goal Navigation],
    presenter: [Chi Wei, Yeh],
    paper_authors: [
      Jianhao Jiao, Jinhao He, Changkun Liu, Sebastian Aegidius,
      Xiangcheng Hu, Tristan Braud, Dimitrios Kanoulas
    ],
    paper_venue: [ICRA 2024],
    date: rvl-date("2026-02-10"),
  ),
  footer: self => self.info.institution,
)

// Cover
#rvl-title-slide()


= Opening
== Outline
- Introduction
- Method
- Experiment
- Conclusion

== Introduction

- Visual localization estimates camera pose from images, enabling reliable navigation.
- LiteVLoc seeks metric accuracy with a lightweight topo metric map under sparse observations.
- It reduces map burden and is validated in image goal navigation using goal images.

#speaker-note[
  1. 視覺定位的核心是從當前相機影像推回相機在環境中的姿態，這對於導航而言十分關鍵，因為只要定位不穩，路徑規劃與控制就會失去參考座標，整個系統就很難可靠運作
  2. 傳統上要做高精度定位，常見做法是先建立很完整的度量地圖，再把當前影像對到這張地圖上。問題是這類地圖通常很重，儲存與管理成本高，而且環境一旦改變，就需要頻繁維護，否則定位品質會下降
  3. 這篇論文仍然度量層級的定位精度前提下，將地圖做得更輕量。它採用拓樸結構描述可達性與連通關係，同時保留少量度量資訊來支撐姿態估計
  4. 這種地圖天生稀疏實務上定位會更難。LiteVLoc 的差異點在於，不依賴大型的三維重建來撐起定位，而是把重點放在「影像匹配能力」與「幾何求解」的結合，讓稀疏地圖也能給出度量姿態。直觀來說，就是用學習式的特徵與匹配提高在外觀變化下的對應穩定性，再用幾何方法把這些對應轉成可用的姿態估計，達到降低地圖負擔但仍保有精度的目標。
  5. 它不只停留在定位指標上，而是把整個方法放到 image-goal navigation 的任務來驗證。也就是使用者用一張目標影像來指定要去的位置，而不是給一組座標。這在應用上比較直覺，因此也能凸顯這套 map-lite 定位對導航任務的價值
]

= System Overview
== Method

#grid(
  columns: (1fr, 1fr),
  gutter: 0.25in,
  [\
    #set text(size: 20pt)
    *Goal*: Support image-goal navigation with metric 6DoF localization. \
    *Constraint*: Avoid heavy full metric 3D reconstruction maps.

    Thus, they use a lightweight topo-metric map to address the problem.
  ],
  block[
    #show figure.caption: set text(size: 16pt)
    #figure(
      image("figs/litevloc_overview.png"),
      caption: [Pipeline of LiteVLoc.],
    )
  ],
)

#speaker-note[
  1. 這張圖先只回答一件事：LiteVLoc 的資料流怎麼走，哪些模組要做什麼輸入輸出。
  2. 系統的輸入是當前觀測，包含影像，還有深度，以及里程計。輸出是連續的相機姿態，並且可以接到導航。
  3. 第一段是 Global Localization。它做影像檢索，目標是快速找到地圖上最像的節點，產生一個拓樸層級的初始化。這一步不追求很準，追求的是不要從完全錯的地方開始。
  4. 第二段是 Local Localization。它只在候選附近做更強的匹配，用 dense matching 找到大量對應點。接著利用深度把 query 影像的像素轉成三維點，形成二維到三維的對應，最後用 PnP 加 RANSAC 解出度量的 6DoF 姿態，並且用 inlier 數量判斷這次定位可靠不可靠。
  5. 第三段是 Pose SLAM。因為 Local Localization 的結果不會每一幀都有，而且偶爾會失敗。Pose SLAM 把高頻的里程計當作連續追蹤來源，把低頻但更準的 VLoc 結果當作全域約束，做因子圖最佳化，最後輸出一條連續且穩定的軌跡。
  6. 這張圖的重點是分工。檢索負責找對地方，匹配加幾何負責把外觀相似變成可解的幾何約束，因子圖負責把零散的準確訊息變成導航能用的連續姿態流。
]

= Notation & Inputs (Estimator view)
== Method

#grid(
  columns: (1.6fr, 0.8fr),
  gutter: 0.25in,
  block[
    #set text(size: 20pt)
    State:

    pose $scr(x) = [t, q]$ where $t in bb(R)^3$, $q$ is a unit quaternion.

    At time $k$, estimate $scr(x)_k$ given:

    - map $cal(M)$
    - observation $cal(Z)_k = {I_k, D_k}$ (RGB image + depth)
    - odometry (motion) input $cal(U)_k$
    - previous estimate $hat(scr(x))_(k-1)$
  ],

  block[
    #set text(size: 22pt)
    Estimator formulation:
    $
      f_("est")( cal(M), cal(Z)_k, cal(U)_k, hat(scr(x))_(k-1) )
      arrow.r
      scr(x)_k
    $
  ],
)

#speaker-note[
  1. 這頁用估計器的角度把問題寫清楚。狀態只包含相機姿態，也就是平移 t 和旋轉 q。
  2. 在時間 k 要估 $scr(x)_k$，需要四類輸入。
  3. 第一類是地圖 $cal(M)$。這不是 dense 的三維重建，而是 topo metric 的節點資料庫，每個節點帶有關鍵幀觀測以及對應的位姿資訊。
  4. 第二類是當前觀測 $cal(Z)_k$。這裡是 RGB 影像 I_k 加上深度 D_k。深度的作用是把影像上的像素點提升成三維點，後面才能做二維到三維的幾何求解。
  5. 第三類是運動輸入 $cal(U)_k$，也就是里程計提供的相對運動。它頻率高，適合用來做連續追蹤，但長時間會累積漂移。
  6. 第四類是上一時刻的估計 $hat(scr(x))_(k-1)$。這讓估計器可以遞迴運作，平常依靠運動模型往前推，遇到可靠的視覺定位時再校正。
  7. 因此這個 f_est 的工作就是把地圖提供的量測約束，和運動提供的連續性約束，整合成當前的姿態輸出。
]

= Optimization lens
== Method

#grid(
  columns: (1fr, 1fr),
  gutter: 0.25in,
  block[
    #block[
      #set text(size: 20pt)
      We can view pose estimation as minimizing 2 types of consistency:
      - Motion consistency
      - Measurement consistency
    ]

    #v(0.65em)

    #block[
      #set text(size: 23pt)
      $
        arg min_(scr(x)_k) [
          f_u (scr(x)_k, cal(U)_k, hat(scr(x))_(k-1)) +
          f_z (scr(x)_k, cal(M), cal(Z)_k)
        ]
      $
    ]
  ],

  block[
    #set text(size: 20pt)
    Key decomposition used by LiteVLoc:

    #v(0.65em)

    1. Compute a visual localization prior $hat(scr(x))^("VLoc"_k)$ from $cal(M), cal(Z)_k$
    2. Fuse $hat(scr(x))^("VLoc"_k)$ with odometry in Pose SLAM (factor graph optimization)
  ],
)

#speaker-note[
  1. 作者作為前提說道本篇論文方法的核心思想在於把 VLoc + Pose SLAM 的設計以標準的最佳化問題視角解之
  2. 式子中的 f_u 衡量 propagated pose ，是用 U_k 和前一時刻的狀態，直覺上它就是在推算出合理的下一步。這部份的更新頻率會很高，但同時可預期的會累積漂移； f_z 衡量 predicated measurements 和實際觀測之間的偏差，就是把候選 x_k 拿去預測相機應該看到什麼，再跟 Z_k 做比較，我們希望它越像越好。這部份可能會比較準確，但其低頻且可能因匹配失敗而 ourlier
  3.這兩個輸出的是代價，也就是結果有多不合理的分數。我們想要估計出來的 x_k 是合理的，故要最小化得分
  4. 不過這個問題是 non-linear and non-convex ，並不容易解，所以作者採取近似策略：先用視覺定位把 f_z 濃縮成一個 pose prior 然後用 Pose SLAM 把這些低頻但準的 priors 當成因子圖裡的約束，和高頻的 odometry 因子一起做融合，得到連續且穩定的軌跡
  5. 後面的消融實驗設計時就有比較 ICP-only (只用 motion) 、Vloc-only (只用 measurement 的零散 prior)以及 PS (融合後的結果)
]

= Map construction
== Method

#grid(
  columns: (1.2fr, 1fr),
  gutter: 0.25in,
  block[
    #block[
      #set text(size: 18pt)

      Keyframe selection as a coverage problem:
    ]
    #block[
      #set text(size: 20pt)
      // Candidates
      $
        cal(C) = {(cal(Z)_i, scr(x)_i)}
      $

      // Objective (cardinality budget)
      $
        arg max_(cal(C)^(\#) subset.eq cal(C))
        cal(h)(cal(C)^(\#))
        quad "s.t."
        |cal(C)^(\#)| <= M
      $

      // Greedy initialization
      $
        cal(C)^(\#)_0 = emptyset
      $

      // Greedy marginal gain
      $
        Delta_m(c)
        =
        cal(h)(cal(C)^(\#)_m union {c})
        -
        cal(h)(cal(C)^(\#)_m)
      $

      // Greedy choice + update (UNION)
      $
        c^*
        =
        arg max_(c in (cal(C) without cal(C)^(\#)_m))
        Delta_m(c)
      $
      $
        cal(C)^(\#)_(m+1)
        =
        cal(C)^(\#)_m union {c^*}
        quad "until"
        |cal(C)^(\#)_m| = M
      $
    ]
  ],
  block[
    #show figure.caption: set text(size: 14pt)
    #figure(
      image("figs/ins_simu_matterport3d_vloc.png", height: 45%),
      caption: [Topo-metric map \
        The green squares and blue lines indicates the graph nodes and traversability edges, respectively. \
        The red arrow indicates the estimated pose.],
    )
  ],
)

#speaker-note[
  1. 這裡的地圖是一張 topo metric graph。節點代表被保留下來的關鍵幀觀測，以及它在地圖座標系中的位姿。邊代表節點之間可達，並且通常也代表兩張影像之間能建立穩定匹配。
  2. 建圖時先有候選集合 $cal(C)$。它是一段已知軌跡上每一筆觀測 $cal(Z)_i$ 搭配位姿 $scr(x)_i$ 的集合。你可以把它理解成已經走過一次環境，沿路收集了很多影像和粗略位姿。
  3. map lite 的關鍵是不能把所有候選都存進地圖，所以要做 keyframe selection。目標是在最多保留 M 個節點的預算下，讓被保留的 keyframes 覆蓋到最多的環境資訊。
  4. 作者把它寫成 budgeted maximum coverage。$h(cal(C)\#)$ 是一個覆蓋度評分，分數越高代表這組 keyframes 對環境的代表性越好。
  5. h 的具體定義會依資料而定。如果有深度，就用 occupancy 相關的覆蓋概念。如果沒有深度，就用空間下採樣的方式，避免在同一個小區域留下太多相似影像。
  6. 這個最佳化問題本質上很難，所以作者用 greedy 近似。從空集合開始，每一步選擇加入後能讓 h 增加最多的那個候選，重複直到選滿 M 個。
  7. 這樣得到的結果是地圖節點數量可控，但仍維持足夠的空間覆蓋，使得後續檢索與幾何求解仍有 anchor 可以依賴。
]


= Coarse to Fine VLoc
== Method

#block[
  #set text(size: 22pt)

  - *Algorithm-agnostic interface*: \ retrieval $->$ correspondences $->$ geometric pose.
  - *GL (topological init)*: \ VPR retrieves nearest node $->$ pose prior.
  - *LL (metric refine)*: \ dense matching $->$ 2D–3D $->$ PnP + RANSAC.
  - *PS (trajectory fusion)*: \ factor graph fuses odom (high-rate) + VLoc priors (low-rate).
]

#speaker-note[
  1. 這邊是 *coarse-to-fine* 的三段式定位： GL 給拓樸初始化、LL 做度量精修、PS 把低頻但準的定位和高頻但會漂的里程計融合成穩定軌跡
  2. “Algorithm-agnostic” ：作者沒有把方法綁死在某個網路或特徵，而是定義清楚每個模組需要的 I/O
    - GL ：需要一個 VPR/檢索系統，輸入 query image ，輸出最相似的地圖節
    - LL ：需要一個 matcher ，輸入 query 與候選 keyframe ，輸出對應點
    - 後端：需要一個幾何 solver ，把對應點轉成 metric pose (PnP/RANSAC)
  3. Global Localization 做的事情很簡單：只要在拓樸層級找一個合理的起點。做法就是用 VPR 描述子把當前影像對到地圖資料庫，取最相似的節點，其節點的 pose 作為初始化 (topological prior)
  4. Local Localization 才是 metric pose 的關鍵：它在 GL 的候選附近做更強的匹配，把「外觀相似」 變成「幾何可解」
    - dense matching ：在 reference-query 之間找大量對應
    - 因為是 RGB-D ，所以可以用 depth + intrinsics 把 query 的像素 lift 成 3D 點，形成 2D-3D correspondences
    - 接著用 PnP 解 (R,t)，再用 RANSAC 抗 outlier ； inlier 數也可作為 LL 成功/失敗的檢查
  5. Pose SLAM 是為了解決頻率與穩定性： VLoc 的 pose prior 不會每幀都有，而且可能失敗；里程計每幀都有但會漂
    - 因子圖裡同時放 odom 因子（相對約束）和 VLoc prior 因子（絕對或半絕對約束），用最佳化把整段軌跡拉回來。
    - 實作上通常是 “有新 prior 才做一次 optimize” ；平時用 odom propagate ，維持高頻輸出
]

= Closed-Loop Navigation
== Method

- *Goal image* $I_g$ $->$ VPR $->$ goal node $n_g$.
- *Graph planning*: Dijkstra on the topo-metric graph $->$ node path.
- *Subgoal tracking*: follow next node $->$ re-localize $->$ switch subgoal online.
- *Local planner*: VLoc (low-rate), control loop (high-rate).

#speaker-note[
  1. 這頁把定位接到 image goal navigation 的閉環流程。目標不是座標，而是一張 goal image I_g。
  2. 第一步是把 I_g 做 VPR 檢索，找到它對應到 topo metric graph 上的 goal node n_g。這等於把使用者提供的影像目標轉成圖上的一個節點目標。
  3. 第二步是在圖上做全域規劃。作者直接在 topo graph 上跑 Dijkstra，得到一條節點序列。這一步很輕量，因為規劃只在節點與邊上運算，不需要在 dense map 上做搜尋。
  4. 第三步是 subgoal tracking。系統一次只追下一個節點，不是一次追到底。每走一段就重定位，並且根據當前所在節點的判定，動態切換下一個子目標，讓閉環更穩定。
  5. 第四步是控制與避障的雙頻率設計。低頻用 LiteVLoc 提供更新過的全域姿態。高頻用里程計和局部控制回路去追 subgoal。這樣就算 VLoc 暫時失敗，控制仍能連續輸出，不會讓導航停擺。
  6. 因此整個導航可用性的關鍵是姿態流必須連續，而這正是 PS 融合存在的原因。
]

= Results
== Experiment Overview

#grid(
  columns: (1.15fr, 0.85fr),
  gutter: 0.25in,
  block[
    #set text(size: 19pt)
    1. *Map-free Relocalization* \
      Single ref + single query $->$ relative pose \
      Metrics: translation error + success rate

    2. *Visual Localization* \
      Sequences $->$ globally-consistent trajectory \
      Metric: ATE (Absolute Trajectory Error)

    3. *Image-goal Navigation* \
      Closed-loop nav with goal images \
      Metrics: navigation time + path length + qualitative behavior
  ],
  block(outset: (x: 10pt, y: 8pt), stroke: 2pt + rgb("#52148f"), width: 300pt, height: 190pt)[
    #set text(size: 18pt)
    #text(stroke: 1pt + rgb("#52148f"))[Key message] \
    LiteVLoc validates \
    1. LL core (matching+PnP),
    2. system-level pose stability (PS fusion),
    3. navigation.
  ],
)

#speaker-note[
  1. 這一頁要把三個實驗「層級感」講清楚：從單次幾何求解，到序列軌跡穩定，再到閉環任務可用性。
  2. 消融實驗分三部份對應 Method 章節：
    - Map-free Relocalization: 只看一張 reference + 一張 query 能不能用 matcher + PnP 解出像對位姿 (LL 的核心難點)
    - Visaul Localization: 把整套 LiteVLoc 跑在序列上量測軌跡誤差 (GL /LL /PS 串起來後始否能穩定定位)
    - Image Goal Navigation: 把定位接上規劃與避障，做閉環導航，同時給量化與實機展示
]

= Results
== Experiment Overview

#grid(
  columns: (1fr, 1fr),
  gutter: 0.25in,
  block[
    #set text(size: 18pt)
    *Implementation*

    - *No fine-tuning* for learning-based models \
    - LL: dense matching $->$ 2D-3D $->$ *PnP + RANSAC* \
    - PS backend: factor graph optimization (*GTSAM*)
  ],
  block[
    #set text(size: 18pt)
    *Compute & Platform*

    - Most experiments: *i9 desktop + RTX 4090* \
    - Real-world VNav: *ANYmal-D* \
      + ZED2 stereo (540 $times$ 960, depth up to 15m) \
      + Intel NUC (planning) + Jetson Orin (vision) \
    - GT poses: Livox Mid360 + Fast-LIO2
  ],
)

#speaker-note[
  作者把大多數實驗 (除了 real-world VNav) 統一跑在同一台桌機: i9 desktop + RTX 4090 ，確保各方法比較時硬體條件一致。
  實機 VNav 則上到 ANYmal-D: 前視 ZED2 stereo (解析度 540x960, 深度可靠到 15m), planning 在 Intel NUC, 視覺處理在 NVIDIA Jetson Orin Ground Truth: 用 Livox Mid360 LiDAR + Fast-LIO2 產生 GT poses (也就是 ATE/導航評估用的 reference) 所有 learning-based model 都不做 fine-tuning ，強調 zero-shot generalization
]

== Datasets & Scenes

#grid(
  columns: (0.75fr, 1.25fr),
  gutter: 0.18in,

  block[
    #v(40pt)
    #show figure.caption: set text(size: 14pt)
    #figure(
      image("figs/fig2a.png", width: 100%, fit: "contain"),
      caption: [Example scenes across datasets.],
    )
  ],
  block[
    #v(60pt)
    #show figure.caption: set text(size: 14pt)
    #figure(
      image("figs/fig2b.png", width: 100%, fit: "contain"),
      caption: [Distribution of camera poses],
    )
  ],
)

#speaker-note[
  先看左邊 Fig2a：它想強調的是跨 domain 的外觀落差。你會看到室內、室外，光照、材質、遮擋差很多；尤其像走廊、樓梯間這種場景，長得非常像，容易造成 perceptual aliasing——也就是你單看影像會覺得「很像同一個地方」，但其實不是。對視覺定位來說，這會讓匹配很容易產生結構化的錯配。

  接著看右邊 Fig2b：它是在展示相機姿態分布。重點是 viewpoint 和距離差異很大，換句話說，query 可能從很不一樣的角度、很不一樣的距離看到同一個地方。這會直接打到 correspondence 的穩定性——因為你如果連「對應點」都找不穩，後面 PnP 再怎麼解都會不可靠。

  所以這一頁其實是在為後面的 Table I 鋪路：LiteVLoc 想要 map-lite，代表幾何 anchor 本來就少，它要維持 metric 6DoF 的關鍵，不是靠大地圖，而是靠更強的 matching 把 correspondences 撐住，讓幾何問題仍然可解。
]


== Map-free Relocalization (Table I)

#grid(
  rows: (1.5fr, 0.9fr),
  gutter: 0.22in,
  figure(
    image("figs/tab1.png", height: 100%, fit: "contain"),
  ),

  block[
    #h(214pt)
    #text(size: 16pt)[Table 1: Map-free relocalization benchmark results.]
  ],
)

#speaker-note[
  接下來進入 Table I：這張表把 Local Localization，也就是 LL 的核心，拆出來做測試。

  任務設定是在只有一張 reference image 和一張 query image 的情況下系統要能估計它們之間的相對位姿。論文先用某個 feature matcher 產生對應點，再把對應點丟進同一個 PnP + RANSAC 幾何求解器。這樣就能做到很公平：你在這張表看到的差距，幾乎就是 matcher 本身在大視角差、外觀差下能不能給出「可用 correspondences」。

  這裡作者一次比較 13 種 SOTA matcher，刻意覆蓋整個 matching 設計空間：從傳統 sparse keypoints（像 SIFT/ORB 當經典下限），到 learned sparse（例如 SuperPoint + LightGlue），到 transformer semi-dense（像 LoFTR / MatchFormer），再到 foundation / 3D prior 的 dense matcher（像 RoMa、DUSt3R、MASt3R）。你可以把它理解成：作者先把 LL 這個最不確定的零件用獨立 benchmark「釘死」，避免後面整體系統看起來很強，其實只是 matcher 恰好吃到偏好。

  % Estimated，也就是到底有多少比例真的解得出來，這是可靠性；門檻內的 precision，例如 [5cm, 5°] 或 [25cm, 5°]，這是在問「解出來是不是夠 metric 可用」；Time(ms)，因為 LiteVLoc 的主張不是只追求最準，而是要可部署。

  這張表的結論就是：在這些大外觀差、大視角差的資料集上，MASt3R 整體表現最好、而且時間也有競爭力，所以後續 LiteVLoc 的 LL 就選 MASt3R 當 matcher。
]


== Visual Localization (Sim) (Table II)

#grid(
  columns: (1.2fr, 0.8fr),
  gutter: 0.22in,

  block[
    #show figure.caption: set text(size: 14pt)
    #figure(
      image("figs/tab2.png", width: 100%, fit: "contain"),
    )
    #h(80pt)
    #text(size: 16pt)[Table 2: ATE on simulated sequences.]
  ],

  block[
    #v(10pt)
    #h(10pt)
    #set text(size: 18pt)
    *Baselines*

    - *ICP-only*: high-rate, but drifts \
    - *VLoc-only*: accurate when succeeds, low-rate & intermittent \
    - *PS*: fuse odom + VLoc priors
  ],
)

#speaker-note[
  Table I 說明了單次的 LL 之可行性，接下來 Table II 進入序列上的 visual localization：VLoc，導航需要的是一條「連續可用」的 pose stream，偶爾可以做出很準的並不能滿足需求。這也是為什麼還需要 Pose SLAM，也就是 PS。

  ATE 是把估計的整段軌跡跟 ground truth 軌跡做對齊之後，計算每個時間點的平移誤差，再用 RMSE 彙整成一個數字。這裡有兩個很重要的前處理：第一是時間戳配對，第二是座標系 alignment。 ATE 特別敏感於「長期漂移有沒有被校正」——它獎勵的是 global consistency。

  作者把整個系統拆成四種輸出，名稱後面的括號是輸出頻率，這點非常關鍵：它就是在對比「高頻但會飄」跟「低頻但準」怎麼互補。
  (A) ICP(15)：把 ICP 當成 local odometry baseline。它每一步都有、頻率高，但你只積分、不校正，所以序列一長就會飄，ATE 往往會隨路徑變長快速變爛。
  (B) VLoc(1)：這個是低頻的全域 pose prior，你可以理解成它不是里程計，不保證每一幀都有，但成功時很準，能提供回到地圖座標系的錨點。
  (C) PS(15)：這就是 LiteVLoc 的關鍵：把高頻 odom 因子跟低頻 VLoc prior 因子一起放進因子圖做融合，輸出一條更穩、更連續的軌跡。作者用 GTSAM 做 factor graph optimization，你可以把它看成 Pose SLAM / pose graph 形式的融合。
  (D) PS-Opt(1)：這是 batch optimization 的版本，會把歷史一起重最佳化，更像離線後端，用來提供更一致的整體解，或提供更好的 mapping 初值。

  所以你在 Table II 的讀法很簡單：去看長序列、大環境，特別是作者刻意設計包含「走到地圖沒覆蓋區」的序列。在這種情況下，ICP 的 ATE 會爆掉，而 VLoc 跟 PS 能把 ATE 壓下來。這就量化證明了 paper 的主張：只靠 motion 會飄，但只要偶爾有可靠的 VLoc prior，PS 就能把整段軌跡拉回全域一致性。
]


== Visual Localization: Qualitative (Fig. 4)

#grid(
  columns: (1.1fr, 0.9fr),
  gutter: 0.5in,

  block[
    #show figure.caption: set text(size: 14pt)
    #figure(image("figs/fig4.png", width: 100%, fit: "contain"))
    #h(30pt)
    #text(size: 14pt)[Figure 5: Trajectory comparison with ground truth.]
  ],

  block[
    #v(80pt)
    #set text(size: 18pt)
    - ICP drift is *monotonic* without absolute correction \
    - VLoc gives *sparse global anchors* \
    - PS propagates with odom then corrects with VLoc priors
  ],
)

#speaker-note[
  先帶大家看 ICP 的軌跡：它基本上就是 monotonically drift 。因為它沒有任何絕對校正，只是一直把相鄰幀的相對運動積分起來，所以時間越長越偏。

  再看 VLoc：VLoc 的特性是低頻，而且可能會失敗，所以你不一定每一段都有點，但只要成功，它提供的是相對地圖座標系的 global anchor。這種 anchor 的價值不是讓你每一步都很準，而是讓你「回到正確的地方」。

  最後看 PS：PS 的行為可以用一句話描述——平常用 odom propagate 保持連續，高頻輸出；一旦有新的 VLoc prior，就在因子圖裡把整段軌跡拉回來。也就是把「偶爾正確」的定位，變成「連續可用」的 pose stream。這一點其實就是 LiteVLoc 把 VLoc 接到導航任務的必要條件。
]

== Visual Localization (Real) (Table III)

#grid(
  columns: (1.25fr, 0.75fr),
  gutter: 0.22in,

  block[
    #show figure.caption: set text(size: 14pt)
    #figure(
      image("figs/tab3.png", width: 100%, fit: "contain"),
    )
    #h(80pt)
    #text(size: 16pt)[Table 3: ATE on real-world sequences.]
  ],

  block[
    #set text(size: 18pt)
    - Outdoor scenes: dynamic + structureless regions \
    - PS still reduces drift by injecting global priors \
    - Failures align with weak correspondences

    #v(0.6em)
    *Bridge to nav* \
    This robustness is what makes image-goal navigation feasible.
  ],
)

#speaker-note[
  在模擬驗證了 PS 的價值，那 Table III 就把同樣的拆解搬到真實世界，因為真實 outdoor 更容易遇到一些模擬很難完全復刻的困難：動態物體、人群、弱結構區域，還有光照改變。

  這張表的設計還有一個重點：作者不只換場景，也換了 odometry 的來源做對照。你可以把它理解成在問：「不管你的 odom 是哪一種，只要它是高頻但會累積漂移，低頻的 VLoc prior 能不能穩定提供增益？」這也是為什麼你會看到表格裡有不同 odom 來源的比較——一個更像 robot proprioceptive odom，另一個更像 stereo odom。

  第一，真實世界的 ATE 絕對值不一定比模擬漂亮，但 PS 的趨勢仍然成立——它透過注入 global priors 去修掉 drift；第二，失敗通常不是「PS 公式不好」，而是上游 correspondences 變弱，例如重複紋理造成 aliasing、或弱紋理導致匹配不足。

  這張表要傳達的訊息就是——PS 在真實場景仍然能提供足夠穩定的 pose，這才使得 image-goal navigation 的閉環控制成為可行。
]

== Image-goal Navigation (Table IV)


#grid(
  rows: (0.6fr, 1.4fr),
  gutter: 0.45in,
  block[
    #show figure.caption: set text(size: 14pt)
    #figure(
      image("figs/tab4.png", width: 100%, fit: "contain"),
    )

  ],

  block[
    #set text(size: 18pt)
    - *Baseline*: GT localization \
    - *Ours*: LiteVLoc + local planner completes goals with comparable path length \
    - *Trade-off*: extra rotations & re-localization checks can increase time
  ],
)

#speaker-note[
  我先講公平性，因為這張表的 baseline 設計：GTLoc + Falco 代表「定位是上界」的參考，因為它直接用 ground truth localization，等於把定位的不確定性拿掉。你可以把它看成理想情況下的導航表現。

  我們真正要看的是 LiteVLoc + local planner：也就是不靠 GT，而是用 LiteVLoc 提供的 pose 來做規劃與控制。這張表的關鍵訊息我會只抓一個：即使沒有 GT，系統仍能完成任務，而且 path length 不會失控，代表它沒有因為定位亂飄而走出很奇怪的繞路。

  至於時間為什麼可能比較長，作者也給了很合理的解釋：因為相機視野有限，閉環過程中有時會卡 local minima，需要更常旋轉、或更頻繁地 re-localization 檢查，這會把 time 拉長；但 path length 沒有明顯增加，反而是一個好訊號——代表它走的路仍然一致，只是多花了動作去確保定位與觀測條件。
]

== Image-goal Navigation (Fig. 3)

#grid(
  rows: (0.8fr, 0.7fr),
  gutter: 0.22in,
  block[
    #figure(
      image("figs/fig3.png", width: 100%, fit: "contain"),
    )
    #h(210pt)
    #text(size: 16pt)[Figure 6: Trajectory comparison with ground truth.]
  ],
)

#speaker-note[
  這個任務的目標不是座標，而是一張 goal image。系統先用 VPR 把 goal image 檢索到 topo-metric graph 上的某個節點，等於把「想去的地方」對應到一個 goal node。接著在圖上用 Dijkstra 做全域規劃，得到一串節點路徑；執行時不是一次追到底，而是做 subgoal tracking：一次只追下一個節點，走一段就重新定位、必要時切換 subgoal，讓閉環更穩。

  這張圖我想強調的亮點是地圖來源：作者提到地圖可以來自 geo-tagged images，包含手機或 AR glasses。這代表建圖端和導航端可能存在 domain gap——拍圖的相機、視角、甚至時間都不同。但 LiteVLoc 用 coarse-to-fine 的方式：先用 VPR 做拓樸初始化，再用 LL 的 dense matching + PnP/RANSAC 做 metric refine，再交給 PS 融合成連續軌跡，最後才能支撐導航閉環。

  所以最後一句我會這樣收束：LiteVLoc 的價值不在於把 map 做得更大、更密，而是在 map-lite 的前提下，仍然透過「強 matching + 幾何求解 + 因子圖融合」維持 metric localization，讓 image-goal navigation 真的跑得起來。
]


= Conclusion
== Conclusion

- Metric 6DoF from a map-lite topo metric graph.
- LL is the bottleneck. Sparse anchors demand strong correspondences.
- Pose SLAM makes it usable for navigation. It stabilizes low rate priors with odometry.
- Limitation: real time performance and navigation in more complex dynamic environments are still left as future work.

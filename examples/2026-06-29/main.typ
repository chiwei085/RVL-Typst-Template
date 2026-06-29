#import "@preview/touying:0.7.0": *
#import "../../lib.typ": *

// ── Layout helpers ────────────────────────────────────────────────────────────
#let small = 15pt
#let tiny = 12pt

#let detail(body) = [
  #set text(size: 18pt, weight: "bold", fill: RVL_PRIMARY)
  #body
  #v(0.10in)
]

#let twocol(left, right, gutter: 0.28in, columns: (1fr, 1fr)) = {
  set text(size: 18pt)
  grid(columns: columns, gutter: gutter, left, right)
}

#let img(path, height: 2.45in) = block(width: 100%, height: height)[
  #image(path, width: 100%, height: height, fit: "contain")
]

#let ctable(cols, rows, widths: auto, size: small) = {
  set text(size: size)
  set table(stroke: 0.6pt + rgb("#cbd5e1"), inset: (x: 5pt, y: 4pt))
  let header = cols.map(c => table.cell(fill: rgb("#eaf0f8"))[*#c*])
  table(
    columns: if widths == auto { cols.len() } else { widths },
    ..header,
    ..rows.flatten(),
  )
}

#let paper-img = "figs/"

// ── Theme ─────────────────────────────────────────────────────────────────────
#show: rvl-theme.with(
  config-info(
    title: [Safe Interval Motion Planning for Quadrotors in Dynamic Environments],
    paper_authors: (
      "Songhao Huang",
      "Yuwei Wu",
      "Yuezhan Tao",
      "Vijay Kumar",
    ),
    presenter: [Chi Wei, Yeh],
    paper_venue: [ICRA 2025],
    date: rvl-date("2026-06-29"),
  ),
)

#rvl-title-slide()

// ── Outline ───────────────────────────────────────────────────────────────────
#rvl-outline-slide(
  question: [
    How can a quadrotor reason about when and how to pass through a dynamic environment without searching the full space–time state space?
  ],
  sections: ([Introduction], [Method], [Experiment], [Conclusion]),
)[
  #speaker-note[
    在動態環境中，路徑是否安全不只取決於「走哪裡」，也取決於「什麼時候經過」。同一條幾何路徑，早一秒和晚一秒可能得到完全不同的結果。
    因此今天要追問的不是單純「怎麼避障」，而是如何只保留真正影響可行性的時間結構，同時產生安全、平滑且動力學可行的軌跡？

    接下來 Introduction 說明這個矛盾，Method 展示作者如何拆解它，Experiment 檢查這種壓縮是否真的保留了足夠資訊。
  ]
]


// ── Introduction ──────────────────────────────────────────────────────────────
#rvl-slide(title: [Introduction])[
  #detail[Known Dynamic Obstacles: Space and Time Are Coupled]

  #twocol(
    block[
      #set text(size: small)
      *Problem setting*
      - 3D quadrotor navigation with static + moving obstacles
      - Obstacle trajectories known in finite horizon $T = [t_s, t_e]$
      - Goal: safe, dynamically feasible, and smooth trajectory

      #v(0.25em)

      *Why existing methods fall short*
      #set text(size: tiny)
      - *SIPP and SIPP-IP*: grid-cell-level intervals; dense-3D pre-computation costly; ignores quadrotor dynamics
      - *T-PRM and VIS-PRM*: roadmap front ends reduce space, but temporal safety still depends on vertex time stamps, edge checks, or short edges
      - *UVD*: useful for topological paths, but assumes *equal temporal domains* and fails when start and end times differ
    ],
    block[
      #img(paper-img + "fig1_representative_experiment.png", height: 3.0in)
      #v(0.22in)
      #grid(
        columns: (1fr, 1fr, 1fr),
        gutter: 0.1in,
        stat-card(text(size: 14pt)[edge-safe], [intervals]),
        stat-card(text(size: 14pt)[temporal], [topology]),
        stat-card(text(size: 14pt)[B-spline], [smooth]),
      )
    ],
    columns: (1.1fr, 0.9fr),
  )

  #speaker-note[
    (右圖是論文開頭的代表性實驗。紫色是 quadrotor 的軌跡，黑色圓柱是靜態障礙物，地上的移動機器人代表動態障礙物。)
    1. 首先必須說清楚的是，這篇論文作者處理的是 3D quadrotor 在同時有靜態障礙物和移動障礙物的環境中導航，而且移動障礙物的軌跡在一段有限時間範圍 T = [t_s, t_e] 內是已知的。由此也可以知曉，這篇論文並沒有要完整解決 quadrotor 在未知動態世界中的自主導航，它更專住在有限的時域內搜尋不同時空拓撲類別。
    2. 這樣的問題設定中最關鍵的直覺在於：空間和時間是耦合的。同一條幾何路徑，在不同時間通過，可能這個時刻安全但其他時刻就撞上移動障礙物。所以不能先把路徑找好、再回頭補時間，時間必須一開始就進到搜尋裡。
    3. 最 naive 的作法無疑是把原本搜尋 3D 空間中的格點，直接升級成搜尋 4D 的 (x, y, z, t) 。一個障礙物在 t=3 秒佔據 (2,3,1)，那個格點就是禁止進入的。問題是，時間如果切成 1000 個格點，搜尋空間就乘以 1000 倍，這個計算成本是不可接受的。

      SIPP 和 SIPP-IP 的做法是：把時間維度分解成每個 grid cell 的 safe interval（安全時段），這樣搜尋時只展開幾個 區間，不是逐個時間步，搜尋量小很多。但問題是：在 3D 的密集網格上，光是替大量格點預先算 safe interval 的前置計算量就很高，在稠密場景下計算時間暴增。更根本的限制是：SIPP 假設 robot 可以瞬間跳到相鄰格點或原地等待，這個動作模型太簡單，但實際的機器人系統有速度、加速度上限、需要距離加減速，這種假設在物理上不成立。

      *T-PRM 和 VIS-PRM* 用採樣 roadmap（隨機撒點後連邊）取代 grid，點與點之間的邊直接是連續線段，大幅縮小空間搜尋規模。Roadmap 的邊是線段，若只在兩端頂點檢查有沒有碰到障礙物，線段中間那段就沒保障。補救方式是把邊的長度限制得很短（這樣中間段近似安全），但過短的邊讓 roadmap 難以跨越空曠空間，品質受限。另一個修法是加入「動力學時間窗」：要求 robot 必須在某個時間段內通過這條邊（配合障礙物的移動時機），但這讓每條邊多了一組嚴格的時序約束——當障礙物越多，全路徑各邊的時序難以同時銜接，很多幾何上合理的路徑因時序對不上而導致 success rate 因此下降。規劃器若要繞開時序衝突只能走更長的路，路徑變得迂迴。

      *UVD* 的作法是判斷兩條幾何路徑是否拓撲等價，在後端最佳化前提供多條拓撲不同的初始 path，降低卡在 local minima 的風險。但 UVD 是設計給靜態場景的，也就是說它假設兩條路徑的起始和終止時間相同。動態場景中，兩條路徑可能在不同時間出發或抵達。
  ]
]

// ── Method 1: Edge Safe Intervals ────────────────────────────────────────────
#rvl-slide(title: [Method])[
  #detail[Edge Safe Intervals: When Can the Quadrotor Traverse?]

  #twocol(
    block[
      #set text(size: small)
      *Collision intervals*
      $
        "CI"(e) = union.big_i (t_i, t_(i+1))
      $
      #set text(size: tiny)
      times when edge $e$ intersects any moving obstacle $X^t_("obs")$

      #v(0.35em)

      #set text(size: small)
      *Safe intervals*
      $
        "SI"(e) = union.big_j (t_j, t_(j+1)), quad t_(j+1) - t_j > t_("min")
      $
      #set text(size: tiny)
      - $(t_j, t_(j+1)) in T without "CI"(e)$, filtered by $t_("min")$
      - $t_("min")$: derived from trapezoidal velocity profile (speed/accel limits)

      #v(0.35em)

      #set text(size: small)
      Edge-level safe $subset.eq$ vertex-level safe

      #set text(size: tiny)
      two safe endpoints $arrow.double.r.not$ safe edge interior
    ],
    block[
      #img(paper-img + "fig4_corridor_inflation.png", height: 4.2in)
    ],
  )

  #speaker-note[
    對於前面那些問題，作者提出了 Edge safe interval，把安全的單位從「格點/頂點在某時刻安全」升級到「整條 edge 在一段時間窗內可以安全走完」。

    1. CI(e) 是這條 edge 的碰撞時間段，在那些時間裡這條 edge 上的線段會和移動障礙物相交。SI(e) 是 safe intervals，把整段時間範圍扣掉碰撞時段後，留下還夠長的那幾段。重點在長度條件 t(j+1) - t(j) > t_min。
    2. t_min 是用梯形速度曲線這個簡易運動模型算出沿這條 edge 的最短可行通過時間。也就是說，safe interval 不是只問「有沒有撞」，還要問「這段時間窗夠不夠真的飛完這條 edge」。
    3. 為什麼 edge safe interval 比 vertex safe interval 更嚴格？這個想法其實挺符合直覺的，因為 edge 在某時間窗安全，沿途端點自然也安全；但兩個端點安全，不代表中間線段在通過過程中也安全。
    4. 右圖是 corridor inflation 示意。這張圖是 x-t 時空圖，橫軸是時間、縱軸是位置。灰色上邊界是不可通過區域；紅色長方塊 1 和 2 是 moving obstacles 在不同時間佔住的位置，所以紅色不是單一空間障礙，而是一段時空禁止區。
    5. 藍色折線是前端給出的初始 skeleton。它在空間上看起來能從左下走到右上，但只看幾何不夠，因為線段如果在錯的時間穿過，就會切到紅色時空障礙。黃色半透明方框是沿著藍色 skeleton 膨脹出的 corridor；每個 corridor 都避開紅色障礙的時間占用，所以它是在時空裡找一串可通過的安全帶。
    6. 紫色帶圓點曲線是後端最佳化後的 B-spline。它不是貼著藍色初始線走，而是在黃色 corridor 內變得更平滑，並且避開紅色障礙。這頁要講的連結是：edge safe interval 先給出不撞的時空通道，後端才能在通道裡平滑化。

    預備問題：如果教授問「edge safe interval 和 vertex safe interval 差在哪裡」，回答要精準：edge 安全保證整段線段在整個時間窗內不撞任何 moving obstacle；vertex 安全只保證兩個端點在某時刻不被佔，線段中間/端點之間的時間可能都有漏洞。
  ]
]

// ── Method 2: Temporal Corridor + UTVD ───────────────────────────────────────
#rvl-slide(title: [Method])[
  #detail[Temporal Corridor and UTVD: Chaining and Classifying]
  #v(-0.06in)

  #set text(size: 14pt)
  #set block(spacing: 0.55em)
  #grid(
    columns: (1fr, 1fr),
    gutter: 0.18in,
    [
      *Temporal corridor*
      $ "TC"(pi) = { I_k | I_k subset.eq "SI"(e_k) inter "SI"(e_(k+1)) } $
      - adjacent SI must *overlap* — relay must connect
      - *directed*: $arrow.r pi equiv.not arrow.l pi$
    ],
    [
      *UTVD*: $s' = alpha s + theta$, $quad alpha in bb(R)^+$, $theta in bb(R)$
      - same class iff $overline(sigma_1(s)\, sigma_2(alpha s+theta))$ collision-free $forall s$
      - static UVD ($alpha=1, theta=0$) fails with unequal time domains
    ],
  )
  #v(0.05in)

  #align(center)[#image(paper-img + "fig2_UTVD.png", width: 86%)]

  #speaker-note[
    這頁接住 Introduction 說的兩個問題：T-PRM 把時序約束加在個別 edge 上，但整條路徑的 safe interval 能不能串起來，沒有保障；UVD 假設兩條路徑的時間域相同，動態場景中不成立。作者分別用 TC 回應第一個問題，UTVD 回應第二個。

    1. 首先看到 TC (Temporal corridor)。核心條件很直接：相鄰兩條 edge 的 safe interval 必須有重疊，才能讓 quadrotor 在換 edge 時不會卡在「上一條還沒結束、下一條已關閉」的時序空檔。這正堵住了 T-PRM 的弱點：T-PRM 對每條 edge 有獨立的時序約束，但整條路徑能不能串起來，沒有明確保證。
    2. Directed 的性質也重要：因為同一條幾何路徑的正向與反向在時間上不等價。後面會有演算法同時檢查 forward path 與 reverse path 的 UTVD 類別，避免只在單一方向上判斷拓撲等價。
    3. 再看 UTVD。靜態 UVD 假設兩條路徑的時間域相同（α=1, θ=0），在動態場景就會失效。UTVD 加入 α（時間縮放）和 θ（時間平移），讓不同時間域的路徑也能做等價比較。
    4. 等價條件的語意：對所有 s，把 σ_1(s) 和 σ_2(αs+θ) 連起來的線段，在對應時間區間 [s, αs+θ] 內必須 collision-free。白話是：能不能用一組時間上合法的線段，把兩條路徑連續地變形到彼此？能就是同一個拓撲類別，不能就是不同類別。
    5. 下方 Fig. 2 把這件事畫出來。左半邊是 2D 地圖：黑色格子是靜態障礙，藍色圓是 start，星星是 end，紅色 a/b/c 是向右移動的障礙物。紫色路徑看起來只是沿著右側通道往上走；如果只看幾何，這個例子很像單一路徑問題。
    6. 右半邊換成 y-t 圖後才看得出差異。紅色直條 a、b、c 代表 moving obstacles 在某些時間佔住某些 y 位置；綠色、紅色、藍色斜線是三條不同時間安排的候選路徑。圖上的虛線是在做 UTVD 的 line-of-sight deformation：黑色虛線表示可行連線，紅色虛線表示變形會撞到障礙物。結論是藍色和紅色可以視為同一個 UTVD class，綠屬於不同 class。

    預備問題：如果教授問「UTVD 在論文裡證得夠完整嗎」，回答是：論文有定義和理論分析，但 `checkEquiv()` 仍要對路徑做離散化，時間解析度和碰撞檢查的細節仍可能影響誤判合併或誤判分開，這是開放問題。
  ]
]

// ── Method 3: Dynamic Connected Visibility Graph ──────────────────────────────
#rvl-slide(title: [Method])[
  #detail[Dynamic Connected Visibility Graph]

  #twocol(
    block[
      #set text(size: small)
      *Guards and Connectors*
      #set text(size: tiny)
      - Start and goal initialized as *Guards*
      - Sampled $v$ becomes *Connector* only if visible Guards $g_1, g_2$ satisfy
        $"SI"(g_1, v) inter "SI"(v, g_2) != emptyset$

      #v(0.4em)

      #set text(size: small)
      *UTVD-guided insertion*
      #set text(size: tiny)
      - Same UTVD class + shorter: *replace* existing Connector
      - Different UTVD class: *add* as new Connector (new topological branch)
      - Both $arrow.r pi$ and $arrow.l pi$ checked for complete coverage

      #v(0.4em)

      #set text(size: small)
      *Result*
      #set text(size: tiny)
      Graph captures distinct *spatiotemporal* topologies, not just geometric paths
    ],
    align(bottom)[#image(paper-img + "fig3_connected_graph.png", width: 100%)],
    columns: (0.78fr, 1.22fr),
  )

  #speaker-note[
    有了 edge safe interval 和 UTVD，Graph 是把兩者組合進 roadmap 建構的機制。Introduction 說 T-PRM 加入 kinodynamic check 後 success rate 反而下降，原因之一是各條 edge 的時序約束難以同時銜接。這個 graph 在建構階段就排除「時序接不上」的 connector，不讓後端去硬補。

    1. graph 的 vertex 分成 Guards 和 Connectors：start 和 goal 一開始是 Guards；一個新採樣點要同時看得到兩個 Guards，而且這兩條 edge 的 safe interval 要有重疊，才有機會成為 Connector。連通條件把 edge safe interval 帶進了 graph 建構，直接回應了「vertex 安全不等於 edge 安全」的問題。
    2. 之後再用 UTVD 和鄰近路徑比較：同一類而且新路徑更短就替換，不同類就保留，形成新的拓撲分支。正反方向都各自檢查，確保不遺漏時序上不對稱的路徑。這讓 graph 捕捉的不只是幾何連通性，還有時序拓撲的多樣性。
    3. 看左圖：黑色長方形是靜態障礙，橘色半透明區塊和箭頭是移動障礙物正在掃過的區域。綠色大圓是 start/end，藍圈是 Guards，紅圈是 Connectors，藍線是 graph 裡保留下來的 valid edges。紅圈通常卡在兩個 guard 可見區域的交界處，作用就是把兩塊可行區域橋接起來。
    4. 左圖中紫色和綠色粗路徑都從 start 到 end，但它們繞過移動障礙物的方式不同：一條比較靠中間穿過，一條沿上方/右側外圍繞行。這些不是單純「長短不同」的候選路徑，而是 UTVD 判斷後要保留下來的不同時空拓撲分支。
    5. 右圖是實際生成的 dense roadmap。綠色細線很多，表示 visibility graph 本身會產生大量可能連線；紅色方塊和紅色虛線箭頭是 moving obstacles 的位置和移動方向，黑色方塊是靜態障礙。橄欖色粗線才是最後挑出的候選 skeleton，從左下方繞過靜態障礙，再往右上方目標前進。
    6. 這頁不能支持「成功率更高」，那要 Experiment 說；這頁能支持的是 graph 的結構設計，為什麼在表示法上比「只靠 vertex timestamp」更完整。
  ]
]

// ── Method 3 ─────────────────────────────────────────────────────────────────
#rvl-slide(title: [Method])[
  #detail[B-Spline Optimization: All Four Cost Terms]

  #twocol(
    block[
      #set text(size: tiny)
      #set block(spacing: 0.45em)
      *Control point derivatives* (B-spline, knot span $t_s$)
      $
        V_i = (Q_(i+1)-Q_i)/t_s, quad
        A_i = (V_(i+1)-V_i)/t_s, quad
        J_i = (A_(i+1)-A_i)/t_s
      $

      *Full objective* $quad min_(Q,t) sum_(d in {c,"od","ct",f}) lambda_d J_d (Q,t)$

      *Control cost (jerk)*: $J_c = sum_i norm(J_i)^2$

      *Dynamic feasibility*
      $
        J_f = sum_i norm(V_i - v_m)^2 + sum_i norm(A_i - a_m)^2
      $

      *Obstacle margin* $quad J_("od") = sum_i sum_j J_(i j)$, $d = norm(E_j^(-1)(p_i - o_j))$
      $
        J_(i j) = cases(0 & "if" d > d_("th"), (d - d_("th"))^2 & "if" d <= d_("th"))
      $

      *Corridor — L1 deviation from cuboid*
      $
        J_("ct") = sum_i (norm(b_(l,j) - Q_i)_1 + norm(Q_i - b_(u,j))_1)
      $
    ],
    align(horizon)[
      #image(paper-img + "fig5_backend_optimization.png", width: 100%)
    ],
    columns: (0.82fr, 1.18fr),
  )

  #speaker-note[
    接著我們拿著帶有時序拓撲保障的 skeleton，把它優化成 quadrotor 飛得了的軌跡。

    1. 先讀 B-spline 的 control point derivative 推導。Trajectory 用 uniform B-spline 的 N_c 個 control points Q_i 表示，knot span 固定為 t_s。速度 V_i、加速度 A_i、jerk J_i 都由相鄰 control points 的差分得到。這個 finite difference 的形式讓梯度計算變得直接，適合做 gradient-based optimization。
    2. 最佳化的總目標是對四個 cost 加權求和，最小化 Q 和 t（knot span）。四個 cost 各有分工：J_c 管平滑（jerk）、J_f 管 dynamic feasibility（速度/加速度超限）、J_od 管動態障礙物距離、J_ct 管 corridor 邊界（L1 偏差）。
    3. J_od 的距離函數 d(p_i, o_j) = ||E_j^(-1)(p_i - o_j)|| 用了 ellipsoid 的係數矩陣 E_j^(-1)，把 Euclidean 距離映射到 ellipsoid 形狀，這樣不同軸向大小的 ellipsoid 都能正確量距離。
    4. J_ct 用 L1 norm 是借助 B-spline 的 convex hull property：只要把 control points 約束在 cuboid 內，整段曲線就會落在安全 corridor 內；用 L1 violation 取代硬性約束，讓 gradient-based 最佳化更容易收斂。
    5. 右圖是 Fig. 5。它不是一張靜態俯視圖，而是同一個場景在 2s、5s、7s、9s 的四個快照。黑色方塊是靜態障礙，紅色帶編號方塊是 moving obstacles 在該時刻的位置，半透明黃色長方形是前端膨脹出的 corridor，藍紫色曲線是初始/參考 skeleton，粉紅色曲線是後端最佳化後的 trajectory。
    6. 綠色圈出的地方是這張圖最該講的視覺重點：在 2s 左上，quadrotor 剛進 corridor，附近有 obstacle 1；在 5s 右上，路徑下方的 obstacle 7 和右側 obstacle 4 會限制粉紅色曲線怎麼轉；在 7s 左下，粉紅色軌跡正接近 obstacle 4；到 9s 右下，quadrotor 接近終點，同時 obstacle 7/8/9 改變了可通過區域。換句話說，後端不是在一張固定地圖上修線，而是在多個時間快照中同時保持距離。
    7. 圖和公式的對應是：黃色 corridor 對應 J_ct，紅色 moving obstacles 對應 J_od，粉紅色曲線沒有劇烈折角對應 J_c 和 J_f。重點不是「路最短」，而是「最佳化後的軌跡如何在 corridor 內繞開移動障礙物、又維持平滑」。
    8. 這頁不能支持「控制代價一定較低」，那只是最佳化設計的機制解釋，真正有沒有把 jerk 降下來，要等 Table I。這裡提供的是「為什麼作者預期軌跡會更平滑」的機制，不是已驗證的結果。

    預備問題：如果教授問「corridor cost 為什麼用 L1 不用 L2」，回答是：L1 violation 讓 penalty 在邊界外是線性增長/邊界內是零，這樣 control point 被「推進去」的梯度比 L2 更乾淨，也更容易配合 B-spline convex hull property 做分析。
    預備問題：如果教授問「knot span t_s 是固定的還是也在最佳化」，回答是：paper 描述的是先以固定 knot 最佳化 control points，再疊代調整時間配置（iterative time allocation refinement），最後從多條候選 trajectory 選最小 control cost 那條。
  ]
]

// ── Experiment: Protocol ──────────────────────────────────────────────────────
#rvl-slide(title: [Experiment])[
  #detail[Protocol: Three Density Levels, Seven Front-End Planners, Four Metrics]

  #twocol(
    block[
      #set text(size: small)
      *Benchmark setup*
      - 100 trials per map level
      - Map re-generated every 3 trials, random start and goal
      - Success = find a collision-free trajectory to goal

      #v(0.4em)

      *Front-end planners compared*
      - *SIMP* (proposed)
      - T-PRM, T-PRM(dyn)
      - VIS-PRM, VIS-PRM(dyn)
      - SIPP, SIPP-IP

      #v(0.4em)

      #set text(size: tiny)
      *(dyn) variants*: add kinodynamic check via trapezoidal velocity profile to the original planner
    ],
    block[
      #set text(size: small)
      #ctable(
        ([Map level], [Density range], [Dynamic obstacles]),
        (
          ([Sparse], [[0, 0.01]], [[0, 20]]),
          ([Moderate], [[0.05, 0.1]], [[20, 40]]),
          ([Dense], [[0.15, 0.2]], [[40, 60]]),
        ),
        widths: (0.95fr, 1.25fr, 1.45fr),
        size: small,
      )
      #v(0.28in)
      #grid(
        columns: (1fr, 1fr),
        gutter: 0.14in,
        stat-card([100], [trials per level]), stat-card([3], [density levels]),
        stat-card([4], [evaluation metrics]), stat-card([3], [trials per map]),
      )
    ],
  )

  #speaker-note[
    1. 作者的 benchmark protocol 把環境密度、動態障礙物數量、評估指標都講清楚了。
    2. 先看右邊的表格——這是環境設定表。三個 map level：Sparse 的密度指數是 [0, 0.01]、動態障礙物 [0, 20]；Moderate 是 [0.05, 0.1] 和 [20, 40]；Dense 是 [0.15, 0.2] 和 [40, 60]。這裡沒有好壞，只是在定義 benchmark 的難度分層。
    3. 左邊補充 trial 規則：每種 map type 跑 100 次，每三次換地圖，start 和 goal 隨機選無碰撞位置。白話講，作者不是在同一張固定地圖上反覆跑到過擬合，而是持續換場景測穩定性。
    4. 所有 baseline 都在同一個模擬環境跑。包括本文的 SIMP，還有 T-PRM、VIS-PRM、SIPP、SIPP-IP，以及加入動力學檢查的 T-PRM(dyn)、VIS-PRM(dyn)。(dyn) 的意義是把梯形速度曲線納入，確認 edge 的 traversal 在動力學上是否可行——這樣後面才能分辨：提升到底是來自 roadmap 結構、safe interval、還是動力學檢查。
    5. 模擬環境是這間實驗室自己維護的工具，他們專門做四旋翼，framework 也是自己代代傳下來的。場景是一個有界的三維空間，裡面同時有固定不動的靜態障礙物，以及大小不一的橢球形動態障礙物在空間中移動。動態障礙物走的是最小加速度軌跡——加減速平滑、不會突然轉向或瞬間改速，讓測試條件更接近真實場景。成功定義很直白：quadrotor 從起點飛到終點、中途不碰任何東西就算成功。

    預備問題：如果教授問「success 的定義是前端找到路徑就算，還是後端成功也算」，回答要分清楚頁面範圍：這裡講的是前端 benchmark，所以 success 是「找到一條無碰撞的路徑到達 goal」；後端最佳化的比較是再後面另外看。
  ]
]

// ── Experiment: Front-end results ─────────────────────────────────────────────
#rvl-slide(title: [Experiment])[
  #detail[Fig. 6 Front End Benchmark Across Three Map Levels]

  #block(width: 100%, height: 4.35in)[
    #image(paper-img + "fig6_benchmark_results.png", width: 100%, height: 100%, fit: "contain")
  ]

  #speaker-note[
    這張圖的核心故事只有一句話：success rate 是 SIMP 和 baseline 差距最大的指標，而且差距隨密度愈來愈明顯。其他三個子圖揭示的是 baseline 各自的問題在哪裡。

    1. 先看 success rate。Ours 在三種密度下都維持最高，dense 仍達約 97%。T_PRM 在 sparse 還跟得上（~93%），但 moderate 和 dense 掉到 63% 以下繼續下滑。VIS_PRM 在 moderate/dense 甚至比 T_PRM 略低，因為它純靠幾何可見性加時間戳記，沒有任何 safe interval 完整性保障，論文直接說它 "has a lower success rate as moving obstacles increase, compared with methods that leverage the completeness of safe interval planning"。SIPP-IP 全程是七個方法裡成功率最低的，大約在 20–40% 之間。
    2. 再看 T_PRM vs T_PRM(dyn)。T_PRM(dyn) 的 success rate 比 T_PRM 更低，flight time 則大幅飆升——圖上 T_PRM(dyn) 的 flight time box 在 sparse 就已明顯高出一截，中位數大約比 T_PRM 高出一倍。論文解釋：T_PRM 靠限制 edge 長度保安全，加入動力學後這個長度限制更緊，大量幾何可行的連線在時序上接不上，成功率因此掉、繞路讓飛行時間增加。這正是 SIMP 設計動機的反面教材：把動力學可行性事後補到 vertex-based 方法上，效果是更差，不是更好。
    3. 對照 VIS_PRM vs VIS_PRM(dyn)，兩者幾乎看不出差別。論文的解釋是：VIS_PRM 用隨機抽取 vertex timestamp，天然就留了足夠的時間冗餘，再加動力學檢查不構成瓶頸。這和 T_PRM(dyn) 形成有意思的對比——edge 長度約束緊的方法加 dynamics 就崩；靠隨機時間戳記的方法加 dynamics 幾乎沒影響。但兩條路都不解決問題：T_PRM(dyn) 主動壞掉，VIS_PRM 則是靠運氣過關，隨機時戳不保證時序一致性。
    4. SIPP 類最值得單獨說。SIPP-IP 的 computation time 在 dense 是七個方法裡最誇張的（box 頂部約 700ms、outlier 超過 1100ms），但它的 success rate 卻是全場最低。這個反直覺的結果對應論文說的：SIPP-IP 常在達到 max expanded vertices 限制後被迫停止，計算愈久、愈容易碰頂、找到的路反而愈少——高 computation + 低 success 兩頭輸。SIPP（非 IP）computation 也明顯比 roadmap 類方法長，是 3D grid 上預計算 time interval 的固有成本。
    5. 哪裡 Ours 沒有明顯優勢？Computation time 上 Ours 和 T_PRM 幾乎在同一水準，並沒有壓倒性快。Path length 的差距也小（論文說 T_PRM path 略長，但不是關鍵差距）。Flight time 在 sparse 場景，T_PRM 原版和 Ours 差不多，論文也只說 Ours achieves "relatively low" flight times，不是 lowest。論文沒有特別解釋，但可推測：edge safe interval 讓 roadmap 只能走時窗有重疊的邊，不一定走出時間最短的路線。

    預備問題：如果教授問「SIPP-IP 不是比 SIPP 更完整，為什麼 success 更低」，回答：SIPP-IP 以最優解為目標展開更多 vertex，在 3D dense 場景更快碰到 expansion limit 被強制停止，是「用更強演算法但 budget 固定」的陷阱；SIPP 反而不那麼貪婪，所以反而存活更久。
    預備問題：如果教授問「這張圖的 success 是否包含後端最佳化」，回答：不包含，這是 front-end path benchmark。論文 VI.B.1 定義 plan successful 是前端找到 collision-free path；後端軌跡比較在 Table I。
  ]
]

// ── Experiment: Back-end (Table I) ───────────────────────────────────────────
#rvl-slide(title: [Experiment])[
  #align(center + horizon)[
    #set text(size: 17pt)
    #table(
      columns: (1.05fr, 1fr, 1.05fr, 1.05fr, 1.05fr, 1.45fr),
      align: (center, center, center, center, center, center),
      stroke: (x, y) => if y == 2 { (bottom: 0.8pt + rgb("#8FA3BF")) } else { (bottom: 0.4pt + luma(215)) },
      inset: (x: 8pt, y: 6pt),
      table.cell(colspan: 6)[*TABLE I*],
      table.cell(colspan: 6)[*PLANNER COMPARISON*],
      table.header(
        [*Env.*],
        [*Methods*],
        [*Opt.\ Succ.\ Rate*],
        [*Traj.\ Len. (m)*],
        [*Flight\ Time (s)*],
        [*Ctrl. Cost Avg.\ (m²/s⁵)*],
      ),
      table.cell(rowspan: 2)[Sparse], [Ours], [100%], [7.66], [6.04], [17.71],
      [TPRMO], [99%], [7.89], [5.55], [72.67],
      table.cell(rowspan: 2)[Moderate], [Ours], [98%], [7.93], [6.05], [26.20],
      [TPRMO], [97%], [8.11], [5.72], [73.27],
      table.cell(rowspan: 2)[Dense], [Ours], [97%], [7.44], [5.69], [30.53],
      [TPRMO], [97%], [7.52], [5.36], [70.31],
    )
  ]

  #speaker-note[
    Table I 的核心故事：這不是七個方法的全面 PK，而是 Ours（SIMP 前端 + corridor 後端）對上 TPRMO（T-PRM 前端 + 無 corridor 後端）的系統級對比。前端和後端同時都不同，所以不是嚴格的單變數 ablation——但作者把控制代價的差距歸因於 corridor 有其機制依據，不只是猜測（見第 1 點）。

    1. 先確認 TPRMO 是什麼：T-PRM 前端，後端最佳化*不使用 corridor*，改用 Euclidean 距離 obstacle 作為 cost function，加上靜態障礙物的 convex decomposition 策略。兩者後端的最佳化機制在結構上根本不同：Ours 的 optimizer 在 corridor 定義的時空管道內工作，管道本身已保障安全，只需在管道裡最小化 jerk；TPRMO 的 optimizer 對每個障礙物各自用距離 penalty 推開，遇到障礙物就局部閃，高 jerk 是結構性的。這個差異是後端機制決定的，不只是前端路徑品質不同——這正是作者把控制代價差距歸因於 corridor 的依據。嚴格來說，若要完全孤立 corridor 的貢獻，需要「SIMP 前端 + 無 corridor 後端」這組對照，論文沒有提供，是實驗設計的輕度缺口。兩種方法的規劃器被觸發時機相同：「偵測到當前 B-spline 軌跡碰撞」時啟動，前端找到有效路徑才跑後端。
    2. 第二個預期會讓聽眾困惑的問題：前面 Fig. 6 的 T-PRM 前端在 dense 場景成功率只有約 57%，但 Table I 的 TPRMO dense 成功率是 97%——這兩個數字怎麼對得起來？答案在論文的 counting 方式：Table I 的 Opt. Succ. Rate 只計算「前端成功找到路徑」的 trial；前端失敗的 trial 不進入計數。所以 TPRMO dense 的 97% 是「在 T-PRM 前端成功的那約 57 個 trial 中，後端有 97% 成功優化」。Ours dense 的 97% 則是「前端 SIMP 成功率本來就約 97%，幾乎全部 trial 都跑到後端，97% 是近似全系統端對端成功率」。換句話說：同樣是 97%，Ours 約對應 97 / 100 個 trial 成功，TPRMO 約對應 0.57 × 0.97 ≈ 55 / 100 個 trial 成功。這是這張表最重要的陷阱。
    3. 成功率數字本身幾乎一樣（100%/99%、98%/97%、97%/97%），但如上所述兩邊的分母不同。軌跡長度也差不多（差距在 0.2–0.5m 以內）。Corridor 並不會讓路徑在空間上拉長。
    4. Flight time 則 Ours 反而比 TPRMO 慢——三種密度下都是（6.04 vs 5.55、6.05 vs 5.72、5.69 vs 5.36）。這是 Ours 沒有優勢的地方。論文的解釋是：corridor 把飛行的時間窗綁在 edge safe interval 上，quadrotor 必須在指定時窗內通過，不能自由選取最快的飛行節奏；TPRMO 沒有這個時序約束，optimizer 可以純粹找時間最短的路線。換句話說，corridor 用一點飛行時間換來全局平順性。
    5. 真正拉開的是控制代價（Ctrl. Cost，單位 m²/s⁵）：Ours 17.71/26.20/30.53，TPRMO 72.67/73.27/70.31，大約四倍差距。先說這個量是什麼：它是 squared jerk 的時間積分，也就是 ∫ ||jerk||² dt，單位推導是 (m/s³)² × s = m²/s⁵。為何叫「控制代價」？Quadrotor 的推力變化率直接對應 jerk，squared jerk 積分愈大代表飛行過程中推力需要愈劇烈地改變，也就是控制器需要做更多功；這個量低 → 軌跡更平順 → 追蹤更容易、能耗更低。為什麼差這麼多？TPRMO 後端沒有 corridor，optimizer 對每個移動障礙物只能靠距離 penalty 局部反應——障礙物逼近就急衝閃開，累積大量局部高 jerk。有 corridor 的情況下，corridor 本身已保障時序安全，optimizer 只需在幾何有結構的 convex 時空管道裡最小化 squared jerk，不需要對個別障礙物見招拆招，自然平順。
    6. 再注意 control cost 的密度趨勢。Ours 隨密度上升：17.71→26.20→30.53（Dense 比 Sparse 高約 1.7 倍）。TPRMO 幾乎不動：72.67→73.27→70.31。這個對比很說明問題：TPRMO 的高 jerk 是結構性的——不管環境多空曠，沒有 corridor 就是要靠距離 penalty 反應，控制代價無法降下來；Ours 在 sparse 環境 corridor 空間大、平滑化容易，dense 環境 corridor 變緊、平滑化代價才上升。

    預備問題：如果教授問「控制代價低代不代表追蹤一定更好」，回答：這是合理方向，但論文沒有做閉環追蹤的 robustness 量化，不要講太滿。
    預備問題：如果教授問「為什麼 Ours flight time 比 TPRMO 慢」，先用上面第 4 點解釋時序約束；如果再追問「這樣划算嗎」，回答：論文把平滑度（控制代價）列為核心 claim，飛行時間的小幅落後被視為可接受的 trade-off，但論文沒有給這個 trade-off 的定量分析。
    預備問題：如果教授問「為什麼不和其他後端方法比」，這是論文的真實弱點，不要解釋掉。論文的 Table I 只回答了「B-spline 加 corridor 比 B-spline 不加 corridor 更平順」，但沒有回答「這套 B-spline + corridor 後端跟其他 trajectory optimizer（例如 CHOMP、TrajOpt、minimum snap）相比怎麼樣」。B-spline 是作者自己選的設計，讀者沒辦法從這張表判斷 corridor 的好處是否只在 B-spline 框架內成立、換一個 optimizer 是否同樣成立。這是評估設計的缺口。
  ]
]

// ── Experiment: Hardware ─────────────────────────────────────────────────────
#rvl-slide(title: [Experiment])[
  #detail[Hardware Validation: Full Pipeline on a Real Quadrotor]

  #twocol(
    block[
      #img(paper-img + "fig7_hardware_experiment.png", height: 3.8in)
    ],
    block[
      #set text(size: small)
      *Platform*
      #set text(size: tiny)
      - *Dragonfly 230*; *2 × Scarab* as moving obstacles; *3* static cylinders
      - *Vicon*: shared frame + odometry

      #v(0.25em)
      #set text(size: small)
      *Purpose of Vicon*

      #set text(size: tiny)
      Simulation provides these for free; hardware cannot:
      - *Quadrotor pose* — replaces onboard localization
      - *Scarab trajectories* — lets planner build safe intervals
      - Remove Vicon → no safe intervals → *pipeline breaks*
    ],
    columns: (1.2fr, 0.8fr),
  )

  #speaker-note[
    這頁不是在做定量比較，而是在回答一個更基本的問題：整套系統能不能在真實物理平台上閉合？

    1. 先理解 Vicon 為什麼是這個實驗的核心依賴，而不只是輔助工具。論文假設「移動障礙物的軌跡在有限時間範圍內已知」，模擬中這是免費的——simulator 直接給 ground truth。真機上要滿足同樣假設，需要兩件事：(a) 知道 Scarab (發音： scare-ub) 在哪、接下來往哪走，才能算 edge safe interval；(b) 知道 quadrotor 自己的精確位置，才能在 corridor 裡追蹤軌跡。Vicon 同時提供這兩件事——追蹤 Scarab 位置給 planner，提供 quadrotor pose 給控制器。沒有 Vicon，(a) 演算法的 safe interval 無從計算，整個 pipeline 直接失效。

    2. 先說每個硬體的角色和代表什麼。Dragonfly 230 是 Kumar lab 自己開發的研究用 quadrotor，搭載 ModalAI VOXL 飛控板 (從時間上推理應該是第一代 VOXL，我們之前看的 starling-2 上面放的是 VOXL 2 飛控版)，不需要靠地面工作站遠端計算。前向 ToF camera 是主動式深度感測，設計上用來偵測前方障礙物；下向 tracking camera 提供光流估計，讓 quadrotor 在水平方向上有穩定的速度回授。這台機器是 Kumar lab 長期做 agile flight 研究用的平台。兩台 Scarab 是大學研究用的地面機器人，每台各帶 Hokuyo UTM30LX——這是一顆業界常見的 2D 雷射掃描儀，30 米範圍、270 度視角，在室內環境夠精確。Scarab 的雷射用於它自己的即時定位和導航（讓它沿矩形軌跡自主移動）。Scarab 的位置對 SIMP 的輸入來自 Vicon，不是 Scarab 自己廣播。i7-8700K 是桌機等級高效能 CPU，讓 Scarab 能做即時 SLAM 和自主導航——移動障礙物是真的在自主移動，不是用遙控或預錄腳本驅動，這讓它的動態更接近真實場景。

    3. 2 台 Scarab + 3 個靜態圓柱這個配置，遠比模擬的 dense 場景（40–60 個動態障礙物）簡單。它只是要驗證整條鏈路能閉合。

    4. 圖的解讀：俯視圖中紅色多邊形是 Scarab 移動障礙物、黑色多邊形是靜態圓柱、紅色曲線是 quadrotor 實際軌跡、綠色箭頭是 odometry。Quadrotor 從右下角起飛，Scarab 沿白色虛線矩形移動，目標點設在黑箱上方，規劃器被觸發後 quadrotor 成功抵達，後續 goal 繼續觸發多次。

    預備問題：如果教授問「這個結果能不能外推到沒有 Vicon 的場景」，回答：目前不能，論文的 future work 明確說要整合 onboard perception 才能處理更複雜、更難預測的移動模式。Vicon 是現在整個系統的感知地基，拿掉它之後感知和定位需要另外解決。
  ]
]

// ── Conclusion ───────────────────────────────────────────────────────────────
#rvl-slide(title: [Conclusion])[
  #detail[Temporal Safety Belongs on Edges, Not Vertices]
  #v(-0.25in)

  #let conclusion-card(title, body) = block(
    width: 100%,
    height: 2.12in,
    inset: (x: 10pt, y: 6pt),
    radius: 8pt,
    stroke: 1pt + RVL_CARD_STROKE,
    fill: RVL_CARD_FILL,
  )[
    #set text(size: 16pt)
    #text(size: 18pt, weight: "bold", fill: RVL_PRIMARY)[#title]
    #v(0.06em)
    #body
  ]

  #grid(
    columns: (1fr, 1fr),
    gutter: 0.05in,
    conclusion-card([Conceptual shift], [
      Moving the unit of temporal safety from vertex to edge is the single design choice that makes edge safe intervals, UTVD, and 4D corridors *composable by construction*.
    ]),
    conclusion-card([Trade-off profile], [
      Success advantage largest in *dense scenes*. SIMP trades time-optimality for structural smoothness.
    ]),

    conclusion-card([What is actually proven], [
      *Representation expressiveness* — that capturing spatiotemporal topology this way yields reliable plans.
    ]),
    conclusion-card([The real open problem], [
      Vicon *bypasses perception*. When obstacle trajectory predictions are noisy or delayed, how edge safe interval errors propagate to safety is untested.
    ]),
  )

  #speaker-note[

    1. 這篇論文最核心的判斷是：把「時間可行性」的保障單位從 vertex 移到 edge。這個選擇不只影響 edge safe interval 的定義——它讓 UTVD 和 4D corridor 都能建立在同一個基礎上。系統的可靠性來自「三個模組共用同一個表示法」，不是來自「每個模組各自更精確」。如果只在 vertex 層做 safe interval，UTVD 的時間域比較就無從保障（因為兩條路徑的時間戳對不齊），corridor 也會變成純幾何約束而丟失時序結構。

    2. Trade-off 的誠實說法是：SIMP 不 claim 最快，它 claim 更可靠、更平滑。Corridor 讓 quadrotor 必須在 edge safe interval 定義的時窗內通過，這個約束犧牲了一點飛行時間彈性（約 0.3–0.5 秒）；但也正因為 corridor 事先保障了時序安全，後端 optimizer 不需要對每個障礙物見招拆招地局部衝閃，控制代價因此從 70+ 降到 17–30 m²/s⁵。這不是 margin 上的改善，是機制上的差異。

    3. 這篇論文的邊界要說清楚：它 prove 的是表示法有效，不是這個演算法是最優解，也不是這套系統可以直接部署。Vicon 把整個感知問題 bypass 了——真機實驗等於是在說「給你完美感知，我的規劃比你好」。這在學術上乾淨，在部署上是另一個問題。

    4. 真正的 open problem 不只是「換成機載感知」，而是：當障礙物軌跡的預測有雜訊或延遲，edge safe interval 的計算誤差會怎麼傳播到成功率和安全性？這篇沒有做 robustness margin 分析，也沒有在預測不確定性下的 stress test。

    5. 給教授一句話：SIMP 示範的不是用更強的演算法蠻力解更大的問題，而是用更合適的表示法，讓時序安全、拓撲多元、軌跡平滑三個需求，各自由一個設計上一致的模組承包。

    預備問題：如果問「為什麼不和 CHOMP/TrajOpt/minimum snap 等後端比」——這是真實弱點，不要解釋掉。Table I 只比了有 corridor vs 沒 corridor 的 B-spline，讀者無法判斷 corridor 的收益是否只在 B-spline 框架內成立，換一個 optimizer 是否同樣成立。

    預備問題：如果問「如果障礙物軌跡預測有誤差怎麼辦」——論文沒有做這個分析。Edge safe interval 是根據已知軌跡算的，預測偏差直接讓 interval 失效，系統沒有 explicit 的 robustness margin。這是論文選擇不回答的問題，也是 future work 的核心。
  ]
]

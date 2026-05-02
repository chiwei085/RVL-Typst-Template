#import "@preview/touying:0.7.0": *
#import "../../lib.typ": *

#show: rvl-theme.with(
  config-info(
    title: [Vision Transformers for End-to-End Vision-Based Quadrotor Obstacle Avoidance],
    paper_authors: (
      "Anish Bhattacharya",
      "Nishanth Rao",
      "Dhruv Parikh",
      "Pratik Kunapuli",
      "Yuwei Wu",
      "Yuezhan Tao",
      "Nikolai Matni",
      "Vijay Kumar",
    ),
    presenter: [Chi Wei, Yeh],
    paper_venue: [ICRA 2025],
    date: rvl-date("2026-05-04"),
  ),
  footer: self => self.info.institution,
)

// Cover
#rvl-title-slide()

#rvl-outline-slide(
  question: [
    For high-speed depth-based quadrotor avoidance, does combining scene-wide spatial context with temporal state yield a more reliable end-to-end controller than designs with purely local spatial encoding?
  ],
)[
  #speaker-note[
    1. 高速避障同時需要空間幾何判斷與時間上的控制平滑。
    2. 這篇研究圍繞一個核心問題：在 high-speed depth-based obstacle avoidance 這個 setting 下，單靠 convolution 是否足夠。
    3. 這裡的 scene-wide spatial context，指的是障礙物邊界、周邊可通行區域，以及多個 obstacle patch 之間的相對位置關係；temporal state 則對應控制輸出的連續性。
    4.後續的 method 會把 spatial bias 和 temporal memory 拆開比較，experiment 再看 collision、generalization、energy cost 誰真的受益。
    5. 預備問題：如果教授問「是不是在替 attention 立題」，回答是沒有，作者是從任務壓力出發，不是從方法趨勢出發。
    6. 預備問題：如果教授問「是不是在否定 CNN」，回答是沒有，這篇 paper 只是在高速避障這個設定下測試卷積的局部歸納偏置是否足夠。
  ]
]

#rvl-slide(title: [Introduction])[
  #grid(
    columns: (1.05fr, 0.95fr),
    gutter: 0.28in,
    block[
      #set text(size: 16pt)
      *Target task*

      - High-speed *forward flight* in cluttered, unknown scenes
      - Input: depth image, attitude, and forward speed
      - Output: commanded linear velocity in world frame

      #v(0.55em)

      *Policy view*

      $
        (im_("depth"), q_("att"), v_("fwd"))
        arrow.r
        v_("pred") in bb(R)^3
      $
    ],
    block[
      #set text(size: 15pt)
      *Research Scope*

      - Explore end-to-end perception-to-command control as an alternative to modular pipelines
      - Compare *CNN / U-Net / recurrent / ViT* backbones under the same task
      - Test whether *global attention + memory* helps as speed increases

      #v(0.55em)

      *Contributions*

      - First use of *ViT* for end-to-end quadrotor avoidance
      - Five-model comparison under one imitation-learning setup
      - Sim + hardware validation up to *7 m/s*
    ],
  )

  #speaker-note[
    1. 這篇論文所研究的是 local reactive obstacle avoidance：輸入是 depth、attitude、forward speed，輸出是當下的 linear velocity command。
    2. 系統上排除了 mapping、global planning 或 mission-level autonomy。作者真正想研究的是 perception-to-command 這一段，而不是整條 autonomy stack。
    3. (右欄的 Research Scope 再把研究問題縮得更精確)這篇論文在同一個 task 下，比較了 CNN、UNet、recurrent、ViT 這幾類 backbone，觀察速度升高後誰更可靠。
    4. 首次把 ViT 放進 end-to-end quadrotor avoidance、做 controlled comparison，並且有 simulation 到 hardware 的驗證。
    5. 預備問題：如果教授問「為什麼速度升高之後 CNN 可能不夠用」，回答是 CNN 每幀獨立輸出，沒有 internal temporal state，在動態系統的連續控制中容易產生抖動的 velocity command；同時 local receptive field 在障礙物密集的場景可能無法掌握障礙物邊界與周邊可通行區域的整體幾何關係。速度一高，這兩個弱點都會被放大，因為留給感知與控制的時間壓縮了。
    6. 預備問題：如果教授問「這是在說要取代 modular pipeline 嗎」，回答是論文的立場是 explore，不是 replace。modular baseline 在 Experiment 中仍有直接比較，結果是 modular 方法在特定速度下設計良好，但在速度範圍改變時擴展性較差；end-to-end 方法在 1–5 m/s 整個速度區間維持較低的 collision rate。
    7. 預備問題：如果教授問「為什麼輸出是 velocity，不是 trajectory」，回答是作者刻意研究 reactive end-to-end control，而不是中間表示加 planning。輸出 velocity command 讓模型直接對障礙物做即時反應，不需要另外的 trajectory optimizer。
    8. 預備問題：如果教授問「為什麼只用 depth」，回答是論文只主張 depth 在 prior work 中常見且有效，這裡不要延伸成 sensor superiority claim。
  ]
]

#rvl-slide(title: [Method])[
  #text(size: 20pt, weight: "bold", fill: rgb("#002060"))[Depth-to-Control via Teacher-Student Imitation]
  #v(0.2in)

  #grid(
    columns: (0.92fr, 1.08fr),
    gutter: 0.28in,
    block[
      #set text(size: 16pt)
      *Teacher-student formulation*

      $
        pi_("expert")(s_t, o) = a_t
      $

      $
        s_(t+1) = cal(T)(s_t, a_t),
        quad
        a_t ~ pi_("expert")(s_t, o)
      $

      $
        pi_("student")(s_t, im_("depth", t)) = a_t
      $

      #v(0.45em)

      *Supervision target*

      $
        L(theta)
        =
        bb(E)_(tau ~ cal(D))
        [
          1/T sum_(t=0)^(T-1)
          norm(v_("cmd")(t) - v_("pred")(t; theta))_2^2
        ]
      $

      #v(0.55em)

      - Student sees depth, not obstacle geometry
      - Input size: *60 x 90*
    ],
    block[
      #image("figs/fig2.png", width: 100%)

      #v(0.35em)

      #stat-card([Shared I/O template], [
        #set text(size: 15pt)
        $
          phi(im_("depth"))
          op
          [q_("att"), v_("fwd")]
          arrow.r
          v_("pred")
        $
      ])
    ],
  )

  #speaker-note[
    1. 這頁是在講，作者怎麼把高速避障改寫成一個可以學習的模仿問題。做法是先假設有一個 privileged expert，也就是一個比學生看得更多的 teacher：它直接知道障礙物在哪裡，所以能先給出「現在應該往哪個方向飛」的速度指令，再讓學生去模仿。
    2. 第一條式子就是在定義這個 teacher。輸入是目前的飛行狀態 s_t 和障礙物資訊 o，輸出是動作 a_t。白話講，就是 teacher 不用只靠深度影像猜，它手上本來就有障礙物幾何這張答案卡。
    3. 第二條式子是在講訓練資料怎麼收。作者的作法是讓 expert 真的在模擬器裡一段一段往前飛，沿著一整條飛行過程持續做決策。每走一步，系統都根據現在的狀態和動作，更新到下一個狀態。與此同時當下這一刻看到的 depth image 和 expert 給的動作會被一起記錄下來。
    4. 第三條式子才是 student 真正要學的 mapping：因為 student 看不到 obstacle locations，只能拿當前 state 加 depth image 來預測同樣的 action。這是整篇 paper 的核心約束，作者想要測的是 perception model 能不能從 depth 裡自己恢復出足夠的避障幾何（也就是哪些地方被障礙物擋住、哪些空間仍然能安全穿過）。
    5. 下面這個 L2 imitation loss 的意義是：對於每一個 timestep t，它都會拿 student 預測的 velocity command 去跟 expert command 做比較。更精確地說，這個 loss 會先取每個 timestep 的 velocity 誤差向量，計算它的 L2 距離平方，再對整條 trajectory 平均。差越小越好；而平方會讓大的錯誤被放大。這個 loss 本身只是在評估「student 模仿 expert 模仿得像不像」。
    6. 作者用故意選用單純的 imitation loss 是怕到後面會不容易分辨性能差異到底是來自 backbone 本身，還是來自 loss 設計。
    7. 右邊的圖與下面的 Shared I/O template 描述了所有模型共同遵守的介面：先把 depth image 丟進 encoder 變成視覺特徵，再和姿態 q_att、前進速度 v_fwd 拼接，最後輸出 v_pred。也就是說，不同模型比較時，輸入輸出格式都固定，真正改變的只有中間的 backbone 與有沒有 temporal module。
    8. 預備問題：如果教授問「為什麼不用 stacked frames」，回答是論文原文給的理由是模型已經拿到 forward velocity；時間資訊若要處理，作者選 recurrent models，而不是影像堆疊。
    9. 預備問題：如果教授問「為什麼不用 RL」，回答是作者刻意選 behavior cloning，因為 RL 會引入 exploration/exploitation tradeoff、reward shaping 與額外超參數調整，這些都會讓 backbone 之間的比較不乾淨。
    10. 預備問題：如果教授問「這算不算 fully end-to-end」，回答是 sensing-to-command mapping 是 end-to-end，但執行端仍保留傳統 low-level control stack，不是直接從像素到 rotor speeds。
  ]
]

#rvl-slide(title: [Method])[
  #text(size: 20pt, weight: "bold", fill: rgb("#002060"))[Short-Horizon Expert with Privileged Obstacle Access]
  #v(0.2in)

  #grid(
    columns: (1fr, 1fr),
    gutter: 0.28in,
    block[
      #set text(size: 16pt)
      *Reactive expert policy*

      1. Build a waypoint grid ahead of the drone
      2. Query collision for each candidate
      3. Pick the free point nearest the center
      4. Convert relative position to $v_("cmd")$

      #v(0.35em)

      *Privileged observation*

      - Obstacle positions/radii within *10 m*
      - Reactive, not dynamics-feasible
      - Collision trials are kept in the dataset
    ],
    block[
      #image("figs/fig3.png", width: 100%)

      #v(0.25em)

      #grid(
        columns: (1fr, 1fr, 1fr),
        gutter: 0.12in,
        stat-card([588], [rollouts]), stat-card([112k], [depth frames]), stat-card([27.5k], [collision frames]),
      )
    ],
  )

  #speaker-note[
    1. 這個 teacher 是一個 privileged reactive planner：每個 timestep 在前方 waypoint grid 上做 collision query，選一個最接近中心且無碰撞的點，再轉成 velocity command。
    2. 右圖就是這個 teacher 在產生 supervision 時，系統同時記下來的兩個視角。左半邊是 teacher 內部真正拿來做決策的資訊，也就是哪些 waypoint 會撞、哪些不會撞；右半邊則是學生之後真正看得到的 onboard depth image。白話講，左圖是在記錄答案怎麼來，右圖是在記錄學生到時候手上會有什麼觀察。
    3. 下面三個數字是在交代資料規模：總共有 588 次 expert rollouts (一次完整的 expert 飛行過程，一整段連續決策資料)，累積 112k 張 depth frames，其中 27.5k 張來自至少有碰撞發生的 trials。白話講，這不是一個只有成功軌跡的乾淨資料集，失敗情況在資料裡也占了可觀比例。
    4. teacher 有特權資訊，但它不是 oracle。因為它每次只看前方一小段距離，做的是很短視的即時反應。同時，它選出的方向，也沒有再經過一個完整的動力學可行性檢查。也就是說，它知道障礙物在哪裡，但不代表它每一步都能規劃出真正飛得順、飛得過去的動作，所以資料裡還是會留下碰撞 trial。
    5. 這也直接連到後面結果的解讀：如果 student 在高速下超過 expert，不代表 imitation 出錯。因果鏈其實是這樣的：expert 在正常情況下會一直重新挑 waypoint；但一旦發生碰撞，原本那套 collision-free waypoint search 會失敗，planner 會短暫卡住，也就是 stall。這種 stall 會讓 expert 在碰撞附近停比較久，所以它的 mean collision time 反而很大。相對地，end-to-end student 學到的是從 depth 直接輸出速度指令，並不會把「一撞到就卡住」這個機制原封不動複製下來，因此即使撞了，也往往更快脫離碰撞狀態。論文後面給的數字就是這個現象：expert 的 mean collision time 在 3 m/s 時是 1.20 秒、7 m/s 時是 0.45 秒，而所有學生模型的最差值只有 0.30 秒與 0.16 秒。這裡先點到為止，Experiment 頁再展開。
    6. 預備問題：如果教授問「為什麼要特別把 collision frames 的數量列出來」，回答可以保守地說：作者是在提醒讀者這個 supervision distribution 並不只包含順利飛過的例子，碰撞相關樣本不是零星雜訊，而是資料集的一部分。至於這是否被作者視為一個刻意的資料增強策略，論文沒有明講。
    7. 預備問題：如果教授問「既然這個 teacher 會留下碰撞，作者為什麼還要這樣設計？這是故意的嗎」，回答要保守地說：是，這個 teacher 本來就不是 oracle，而是作者刻意採用的 short-horizon reactive expert。paper 明寫這篇要研究的是 reactive obstacle avoidance behavior，並且用 privileged obstacle-aware expert 來做 behavior cloning。也就是說，作者要的是一個能在這個 reactive setting 下穩定產生 supervision 的 teacher，碰撞資料則是這個 imperfect teacher 的直接結果。至於「保留碰撞是否本身有額外好處」，論文沒有明講成一個設計主張。
  ]
]

#rvl-slide(title: [Method])[
  #text(size: 20pt, weight: "bold", fill: rgb("#002060"))[Spatial Inductive Bias × Temporal Memory]
  #v(0.2in)

  #grid(
    rows: (0.26fr, 0.74fr),
    gutter: 0.18in,
    block[
      #set text(size: 15pt)
      *Controlled comparison design*

      #align(center + horizon)[
        #move(dx: 3.5em)[
          $
            "encoder"
            arrow.r
            "fusion with " q_("att") "," v_("fwd")
            arrow.r
            "optional LSTM"
            arrow.r
            v_("pred")
          $
        ]
      ]

      - Same task and supervision, mostly *~3M parameters*
      - Difference comes from *spatial bias* and *temporal memory*
    ],
    block[
      #set text(size: 14pt)
      *Attribute map*

      #table(
        columns: (1.5fr, 1.2fr, 0.8fr, 0.9fr),
        align: (left, center, center, right),
        stroke: (x, y) => if y == 1 { (bottom: 0.7pt + rgb("#8FA3BF")) } else { (bottom: 0.35pt + luma(220)) },
        inset: (x: 10pt, y: 6pt),
        table.header([*Model*], [*Spatial bias*], [*Memory*], [*Params*]),
        [*ConvNet*], [local], [--], [235k],
        [*LSTMnet*], [local], [yes], [2.95M],
        [*UNet+LSTM*], [multi-scale], [yes], [2.96M],
        [*ViT*], [global], [--], [3.10M],
        [*ViT+LSTM*], [global], [yes], [3.56M],
      )
    ],
  )

  #speaker-note[
    1. 這頁的主軸是：作者把模型比較拆成兩個很具體的問題。第一個問題是，模型看影像時到底偏向看局部細節，還是能把比較大範圍的空間關係一起考慮進來 (spatial inductive bias)第二個問題是，模型做控制時有沒有記住前幾個 timestep 的資訊 (temporal memory)
    2. 上面這條 shared template 保證了所有模型都做同一件事：吃同樣的 depth、attitude、forward velocity，輸出同樣的 velocity command。
    3. (下方這張表讀成一張定位圖)`local` 的意思是模型主要靠附近的小區塊來判斷，所以 ConvNet 和 LSTMnet 都屬於比較局部的看法；`multi-scale` 的意思是它會同時保留粗的結構和細的邊界，所以 UNet+LSTM 站在中間；`global` 的意思是模型比較有能力把畫面裡相隔較遠的區域一起關聯，所以 ViT 和 ViT+LSTM 放在另一端。`Memory` 那一欄則更直觀：寫 `yes` 的，就是模型除了看現在這張圖，還會把前面幾步的資訊帶進來。
    4. 最右邊的參數欄是在提醒聽眾，作者不是把某一個模型做得特別巨大來硬拚結果。除了 ConvNet 是刻意做成輕量 baseline，只有 235k 參數，其餘幾個模型都壓在大約 3M 到 3.6M。paper 直接說這樣的 model size 是為了讓計算夠快，能放進實際的機器人控制迴路裡。
    5. 預備問題：如果教授問「UNet 為什麼合理」，可以這樣答：UNet 不是拿來做 segmentation 才合理而已，它在這裡代表的是一種中間路線。ConvNet 比較偏局部，ViT 比較偏全局，而 UNet 有 skip connections，能把淺層的局部邊界資訊和深層的較大範圍結構一起保留下來。所以作者放進 UNet+LSTM，是想問「如果我不用 attention，但仍然給模型多尺度資訊，再加上時間記憶，能不能接近或取代 ViT 類模型」。
    6. 預備問題：如果教授問「這個比較完全公平嗎」，回答要分兩層。嚴格來說，不是完全公平，因為 ConvNet 明顯更小；但它仍然有合理性，因為其他四個主要比較的模型都落在接近的參數量級，而且輸入輸出介面、訓練資料、loss、task setting 都固定。作者已經盡量把真正想比較的東西，收斂到 spatial bias 和 temporal memory 這兩個設計軸上。
    7. 預備問題：如果教授問「為什麼沒有純 transformer 架構」，回答是論文在 Section III-C 明寫 fully transformer-based architecture 嘗試過，但表現很差，所以沒有列入比較；作者最後保留的是 transformer encoder 加 fully connected head 的 ViT 版本。
  ]
]

#rvl-slide(title: [Method])[
  #text(size: 20pt, weight: "bold", fill: rgb("#002060"))[Segformer Encoder with Recurrent Head]
  #v(0.2in)

  #grid(
    columns: (0.96fr, 1.04fr),
    gutter: 0.28in,
    block[
      #set text(size: 16pt)
      *ViT encoder*

      - Segformer-inspired encoder with *2 hierarchical transformer blocks*
      - Builds multi-scale spatial context across image patches
      - Produces the visual latent representation before control fusion
    ],
    block[
      #stat-card([Temporal and state conditioning], [
        #set text(size: 16pt)
        *LSTM*

        - Multi-layer LSTM before the FC head
        - Maintains temporal state across timesteps
        - Encourages smoother velocity commands

        #v(0.45em)

        *State conditioning*

        - Quaternion $q_("att")$ and scalar $v_("fwd")$ are concatenated at fusion
        - Keeps the policy grounded in current flight attitude and target speed
      ])
    ],
  )

  #speaker-note[
    1. 這頁我要做的事情很單純：把 ViT+LSTM 這個最核心的 architecture 拆開成三部分講，分別是 ViT encoder、LSTM head、以及 state conditioning。
    2. 左欄先講 ViT encoder。paper 明講的是：它受 Segformer 啟發，用兩個 hierarchical transformer blocks，再接 pixel-shuffle upsampling 和跨層級的 convolutional mixing，作者自己給的結論是這樣能 incorporate information at multiple scales。白話講，就是模型不是只在同一種解析度上看畫面，而是會同時保留比較粗的整體結構和比較細的局部細節。至於「為什麼兩層 hierarchical block 就能做到」，安全講法不是自己推機制，而是回到 paper 原話：multi-scale 來自 hierarchical design 加上後面的 upsampling 與跨層級 mixing，不是單靠 transformer 這三個字。
    3. 右欄再講 recurrent head 與 state conditioning。這裡的因果可以白話成兩件事。第一，LSTM 放在 FC head 前面，代表模型在輸出這一刻的 velocity 之前，會先把前幾個 timestep 的內部狀態也一起考慮，所以它不必把每一幀都當成完全獨立的新問題。第二，q_att 和 v_fwd 被直接拼接進去，代表模型不用只靠 depth image 去反推「我現在機身朝哪裡、目前前進速度是多少」；這些狀態作者直接提供給它。這個因果不只是我們的直覺，paper 後面也做了 ablation，拿掉 orientation 和 forward velocity 後，ViT+LSTM 的表現會變差。
    4. 這頁要把 architecture hypothesis 講清楚，但也要分清楚哪裡是 paper 原話、哪裡是我們的整理。paper 沒有逐字寫成「空間脈絡由 ViT 負責，時間連續性由 LSTM 負責，顯式狀態作為條件」這一句；這是根據整個 model design 做出的整理式解讀。安全的講法是：在這個 architecture candidate 裡，ViT 負責視覺表徵，LSTM 提供時間上的內部狀態，q_att 和 v_fwd 則作為額外條件輸入。也因為它剛好把 global visual encoding 和 temporal memory 放在同一個模型裡，所以它就是最接近 central question 的那個 candidate，真正是否有效，要到 experiment 才能證明。
    5. 預備問題：如果教授問「Segformer-inspired 具體是什麼」，回答可以分三句講。第一，這不是說作者把原版 Segformer 整套搬來，而是借用了它那種 hierarchical 的視覺 transformer 想法。第二，論文明確寫了三個部件：兩個 hierarchical transformer blocks、pixel-shuffle upsampling、以及跨層級的 convolutional mixing。第三，這三者合起來的作用，就是讓不同層級的特徵能重新對齊並互相混合，所以作者才會把它總結成 incorporates information at multiple scales。安全講法是停在這裡，不要再自己延伸到更細的實作細節，因為 paper 本文沒有展開更多。
    6. 預備問題：如果教授問「這一頁能支持 attention 為什麼有效嗎」，回答是不能；這一頁只能描述 architecture hypothesis，真正證據要到 experiment。
  ]
]

#rvl-slide(title: [Experiment])[
  #text(size: 20pt, weight: "bold", fill: rgb("#002060"))[Evaluation Protocol and Platforms]
  #v(0.18in)

  #grid(
    columns: (1fr, 1fr, 1fr, 1fr),
    gutter: 0.12in,
    stat-card([3-7 m/s], [flight speeds]),
    stat-card([90], [Spheres trials / model]),
    stat-card([50], [Trees trials / model]),
    stat-card([30 Hz], [onboard CPU inference]),
  )

  #v(0.22in)

  #grid(
    columns: (1fr, 1fr),
    gutter: 0.28in,
    block[
      #set text(size: 14pt)
      *Simulation evaluation*

      - Flightmare physics + Unity depth rendering
      - *Spheres*: matched obstacle distribution for in-distribution testing
      - *Trees*: unseen tree models for zero-shot generalization
      - Metrics include collisions, path variation, and energy cost
    ],
    block[
      #set text(size: 14pt)
      *Hardware platform*

      - Falcon250 in a motion-capture arena
      - Intel RealSense D435 + Intel NUC 10 for onboard CPU inference
      - Predicted velocity is tracked by the SO(3) control stack
      - Real obstacles are cylinders and blocks, not floating spheres
    ],
  )

  #speaker-note[
    1. 作者沿著速度、環境分布、以及 sim-to-real 三個層次來看。
    2. 上面四個數字先快速報告：simulation 的 forward velocity 是 3 到 7 m/s；Spheres 環境每個模型做 90 個 trials；Trees 這個 unseen environment 每個模型做 50 個 trials；而 real-world deployment 時模型在 onboard CPU 上以 30 Hz 跑 inference。
    3. 左欄是在講 simulation protocol。Spheres 是和訓練分布比較接近的環境，所以它主要拿來看 in-distribution 下，速度提高時各模型的 robustness；Trees 則故意換成沒有在訓練看過的樹木模型，測的是 zero-shot generalization。
    4. 右欄是在講 hardware setting。平台是 Falcon250，深度相機是 RealSense D435，推論跑在 Intel NUC 10 上，所有試驗都在 motion capture arena 進行，所以 state estimate 是可靠的。這樣後面如果看到 real-world result，不要把成功全部歸功於「野外全自主」；這裡的硬體驗證是 controlled indoor trial。
    5. 還有一個很重要的 domain gap 要先講：simulation 裡訓練的是 floating spherical obstacles，但硬體裡測的是 free-standing cylinders 和 blocks。也就是說，real-world 那頁不是在驗證是否見過一模一樣的障礙物，而是在驗證 zero-shot transfer 能不能跨過外觀與幾何差異。
    6. 預備問題：如果教授問「為什麼只測 3 到 7 m/s」，回答是 paper 的重點是 high-speed avoidance，而不是低速精細機動；同時論文也明講硬體實驗做到 7 m/s。
    7. 預備問題：如果教授問「30 Hz 夠不夠快」，回答是作者的 claim 不是追求最高 control frequency，而是這個 model size 可以在 onboard CPU 上 real-time 跑起來；這也是前面為什麼要把大部分模型控制在約 3M 參數量級。
  ]
]

#rvl-slide(title: [Experiment])[
  #text(size: 20pt, weight: "bold", fill: rgb("#002060"))[Backbone Comparison across Speed and Generalization]
  #v(0.18in)

  #align(center)[
    #image("figs/fig4.png", width: 50%)
  ]

  #speaker-note[
    1. 這頁是整個 Experiment 最核心的一張圖。先幫聽眾定錨：4a 和 4b 都是折線圖，x 軸是 forward velocity，y 軸是 mean collision rate per trial，所以線越低越好；4c 是俯視角的飛行軌跡分布圖；4d 是 estimated energy cost，y 軸越低越省能。
    2. 先講 4a。Spheres 環境和訓練分布接近，所以這裡主要是在看 in-distribution 下，速度提高時哪個模型最能撐住 collision rate。圖裡除了學生模型，也畫了 expert 當參照。paper 的結論其實有兩個閾值：超過 5 m/s 之後，ViT+LSTM 是唯一能穩定超過 expert 的模型；而到了 6 m/s 以上，它才開始明顯超過其他學生模型。
    3. 再講 4b。Trees 是 zero-shot unseen environment，所以這張圖看的不是單純性能高低，而是 generalization 到新障礙物分布時會掉多少。論文直接支持的結論是：ViT-based 模型在 Trees 環境明顯優於其他模型；至於這是不是由 attention 機制本身單獨造成，paper 沒有再往下拆解。
    4. 4c 與 4d 則是在補 collision rate 以外的行為特性。4c 是 60 m forward flight 的俯視軌跡圖，可以直接把它講成：每條線代表一次 trial，線群越集中代表 path variance 越小。paper 明寫低變異的不只 ViT+LSTM，ConvNet 也有 significantly less variance；但兩者的差別是 ViT+LSTM 走得更直接，而 ViT 這個沒有 recurrence 的版本則呈現 changing variance。4d 則是 estimated energy cost，作者拿它來比較 command characteristic 是否更平滑、是否更省能。
    5. 這一頁也剛好把前面 method 的兩個設計軸接回來。只看 ViT 或只看 LSTMnet 都沒有 ViT+LSTM 好，所以 paper 的主結論不是某一個單一模組必然最好，而是在這個高速避障任務裡，這個組合式設計表現最強。
    6. 這裡如果要連到 Method 2 的 teacher 缺陷，可以直接補一句：paper 自己說明了 expert 在 collision event 後會 stall，所以 mean collision statistics 會被拉大；因此 student 在高速下超過 expert，不能直接解讀成 supervision 本身有問題。
    7. 預備問題：如果教授問「為什麼不用 success rate 當主圖」，回答是 paper 補充材料裡有 zero-collision success rate，但正文選 collision rate 是因為它對高速下的失敗程度更敏感，不是只有成功 / 失敗二值化。
    8. 預備問題：如果教授問「4d 的 energy cost 能不能直接等價成真實耗電」，回答要保守地說：paper 的表述是 estimated energy cost，對 real drones 的意義是 flight time proxy，不要把它講成真實電池消耗的精準量測。
  ]
]

#rvl-slide(title: [Experiment])[
  #text(size: 20pt, weight: "bold", fill: rgb("#002060"))[Activation Map Analysis across Architectures]
  #v(0.18in)

  #align(center)[
    #image("figs/fig5.png", width: 63%)
  ]

  #speaker-note[
    1. 作者拿來幫前一頁結果做機制層次解讀的分析圖。它在問的是：不同 backbone 到底把 depth image 裡的哪一部分當成主要線索。
    2. 上排是 simulation，下排是 real image。橫向比較三種 backbone 時，可以先講作者原文給的三個觀察：ConvNet 比較像把整個障礙物都亮起來，但對形狀沒有太多區分；UNet 更強調邊界；ViT 則同時把障礙邊緣和周圍脈絡帶進來。
    3. 這頁真正的價值，是把前面 `global context` 那個說法變得可視化。paper 的解讀是 ViT 似乎不只看到單一障礙物邊界，還會把附近可通行空間與鄰近障礙一起納入，這和它在 Trees generalization 上較好的結果是相容的。
    4. 但這頁要講得保守。這些 activation / attention map 只能當成 qualitative evidence，不能單獨當成因果證明；也就是說，它能幫助我們理解模型可能在看什麼，不能單靠這張圖就證明 ViT 一定因此表現更好。
    5. 預備問題：如果教授問「這是不是代表 CNN 看不到全局」，回答不要講太滿。更安全的說法是：在這組可視化裡，ConvNet 呈現出較局部、較整體塊狀的反應；ViT 呈現出較多 surrounding context。但這是這篇 paper 的 qualitative observation，不是對所有 CNN / transformer 的普遍定律。
    6. 預備問題：如果教授問「為什麼沒有放 ViT+LSTM 的 map」，回答是 Fig. 5 的重點在比較視覺 backbone 的表徵特性，所以作者挑的是 ConvNet、UNet、ViT 這三類代表，而不是把 recurrent 版本也混進同一張圖。
  ]
]

#rvl-slide(title: [Experiment])[
  #text(size: 20pt, weight: "bold", fill: rgb("#002060"))[Scaling against Modular Baselines]
  #v(0.18in)

  #align(center)[
    #image("figs/fig6.png", width: 84%)
  ]

  #speaker-note[
    1. 這頁是在問一個系統層次的問題：如果 desired speed 改變，端對端 policy 能不能比 modular planner 更穩定地跟著 scale。
    2. 左圖是 collision rate，越低越好；右圖是 desired velocity 和 achieved velocity 的對照。這裡要幫聽眾加一個讀圖基準：如果 desired 和 achieved 完全相符，理想狀態會貼近對角線；偏離越大，代表速度追蹤越差。也就是說，作者不是只看有沒有撞，還看你有沒有真的飛出指定的速度。
    3. 這個比較的 setting 也要主動和前一頁分開。前一頁 backbone comparison 測的是 3 到 7 m/s；但這一頁 modular baseline 比較看的是 1 到 5 m/s。paper 明寫 FastPlanner 和 Double-Description 原本都是為大約 3 m/s 的飛行設計，所以作者另外做了一個 FastPlanner-scaled，試著把輸出速度拉到 1 到 5 m/s 的範圍。
    4. 但結果顯示，一旦強行 scale，modular 方法不是 timeout，就是 observation 更新跟不上；所以左圖 collision rate 會上升，右圖 achieved velocity 也無法像 ViT+LSTM 那樣跟著 desired speed 線性拉高。
    5. 這幾個 baselines、這個速度範圍、這個障礙物場景下，end-to-end policy 對 speed variation 的適應性更好。
    6. 預備問題：如果教授問「Double-Description 不是幾乎沒撞嗎」，回答是對，所以這頁不能講成所有 modular 方法都差。更精確的說法是：Double-Description 的 collision rate 很低，但它的 achieved velocity 不隨 desired speed 擴展；而 ViT+LSTM 同時兼顧了低 collision 和 speed matching。
    7. 預備問題：如果教授問「這算不算公平比較」，回答是 paper 自己也承認 modular baselines 是 speed-specific methods。這頁比較的公平性不在於每個方法都被調到極致，而在於作者要測試 changing-speed scalability，而這正是 modular baselines 的弱點所在。
  ]
]

#rvl-slide(title: [Experiment])[
  #text(size: 20pt, weight: "bold", fill: rgb("#002060"))[Ablation against State Information]
  #v(0.18in)

  #set text(size: 13pt)
  #grid(
    columns: (1fr, 1fr),
    gutter: 0.22in,
    block[
      *Spheres success rate (%)*

      #table(
        columns: (1.45fr, 0.62fr, 0.62fr, 0.62fr, 0.62fr, 0.62fr, 0.62fr),
        align: (left, center, center, center, center, center, center),
        inset: (x: 7pt, y: 5pt),
        stroke: (x, y) => if y == 1 or y == 2 { (bottom: 0.6pt + rgb("#8FA3BF")) } else { (bottom: 0.3pt + luma(225)) },
        table.header([*Model*], [*3-*], [*3+*], [*5-*], [*5+*], [*7-*], [*7+*]),
        [*ConvNet*], [27], [*63*], [18], [*54*], [10], [*36*],
        [*LSTMnet*], [27], [*45*], [*18*], [9], [9], [9],
        [*UNet+LSTM*], [*36*], [27], [*18*], [9], [*27*], [9],
        [*ViT*], [*81*], [54], [18], [*27*], [18], [18],
        [*ViT+LSTM*], [54], [*72*], [45], [45], [9], [*36*],
      )
    ],
    block[
      *Trees success rate (%)*

      #table(
        columns: (1.45fr, 0.62fr, 0.62fr, 0.62fr, 0.62fr, 0.62fr, 0.62fr),
        align: (left, center, center, center, center, center, center),
        inset: (x: 7pt, y: 5pt),
        stroke: (x, y) => if y == 1 or y == 2 { (bottom: 0.6pt + rgb("#8FA3BF")) } else { (bottom: 0.3pt + luma(225)) },
        table.header([*Model*], [*3-*], [*3+*], [*5-*], [*5+*], [*7-*], [*7+*]),
        [*ConvNet*], [90], [*100*], [*81*], [63], [*60*], [42],
        [*LSTMnet*], [90], [90], [40], [*63*], [36], [*63*],
        [*UNet+LSTM*], [*100*], [72], [60], [63], [45], [*54*],
        [*ViT*], [90], [*100*], [81], [81], [*81*], [80],
        [*ViT+LSTM*], [90], [*100*], [*81*], [80], [50], [*70*],
      )

      #v(0.25em)
      #text(size: 11.5pt, fill: rgb("#4F6078"))[
        `3-/5-/7-`: without $q_("att"), v_("fwd")$; `3+/5+/7+`: with state conditioning.
      ]
    ],
  )

  #speaker-note[
    1. 這頁是 paper 唯一明確獨立出來的 ablation table。先幫聽眾定義方向：這裡的數字是 success rate，所以越高越好。拆法很直接：把前面所有模型都各自重訓一次，拿掉 orientation 和 forward velocity，再跟原本有 state conditioning 的版本比 success rate。
    2. 這個 ablation 要測的不是「state information 有沒有任何幫助」這種空泛問題，而是更精確地問：在高速飛行、而且環境可能變得更不規則時，顯式提供飛行狀態，是否能減少模型自己從 depth 去猜狀態的負擔。
    3. 讀表時要先做兩層切分。第一層是環境：左半張是 Spheres，右半張是 Trees，所以一定要分開看，不能把兩個環境的粗體混在一起讀。第二層才是欄位：每個速度都有一對數字，左邊是沒有 orientation/velocity，右邊是有。粗體是作者標出的較佳數值，所以觀眾只要看同一個模型在同一個環境裡，粗體落在哪一欄，就知道 state conditioning 幫了還是傷了。
    4. paper 的主結論是 ViT+LSTM 在 Spheres 和 Trees 都受益，尤其在速度高、環境陌生時更明顯。ConvNet 的方向則相反：它在 Spheres 受益，但到了 Trees 這個 unseen environment，加入 state 反而讓中高速 success rate 更差；這也是 paper 原文說 ConvNet only benefited in Spheres but performed substantially worse in Trees 的意思。
    5. 這也反過來支持 Method 4 的設計：把 q_att 和 v_fwd 保留在 fusion，不只是工程上方便，而是 paper 確實測到這些顯式 state 對最強模型是有幫助的。
    6. 預備問題：如果教授問「既然 state 有用，那是不是 depth 本身不夠」，回答不要講成 perception 不足。更精確的說法是：depth 負責外部幾何，orientation 和 forward velocity 則是機體自身狀態；作者是在測試兩者結合是否比單靠影像更穩。
    7. 預備問題：如果教授問「為什麼只 ablate 這兩個 state，不 ablate 更多 IMU-like inputs」，回答是 paper 的 student interface 本來就只有 depth、attitude、forward velocity，所以這個 ablation是在現有設計內測最關鍵的顯式狀態，而不是全面 sensor study。
  ]
]

#rvl-slide(title: [Experiment])[
  #text(size: 20pt, weight: "bold", fill: rgb("#002060"))[Zero-Shot Hardware Transfer]
  #v(0.18in)

  #align(center)[
    #image("figs/fig1.png", width: 61%)
  ]

  #speaker-note[
    1. 這頁我會刻意先說清楚 Fig. 1 在論文裡扮演什麼角色。它適合放在 Experiment，但只適合作為 qualitative hardware evidence，不適合拿來當 setup 圖，也不適合拿來當 quantitative superiority claim。
    2. 這張圖上半部的兩個例子是在告訴觀眾：作者不是只做低速 demo，而是真的把同一個 ViT+LSTM policy zero-shot 部署到 real hardware。右圖的 7 m/s 可以直接由 paper 正文支持；左圖上的 4 m/s 則是 figure 本身的圖內標註，不是正文另外展開的數值說明，所以口頭上可以保守講成「一個較低速示例和一個 7 m/s 高速示例」。
    3. 最下面那排 onboard depth images 更重要，因為它把 depth-to-command 這件事具體化了。紅箭頭代表模型輸出的 velocity command，所以這張圖不是單純秀影片截圖，而是在展示模型看到什麼、以及當下打算往哪裡閃。
    4. 這頁也要順手提醒一個限制：paper 自己說 real depth images 會有 simulated training data 裡沒有的 artifact，例如高頻紋理、背景變化、甚至螺旋槳入鏡。所以這頁真正支持的 claim 是 zero-shot transfer 有工作，不是說 sim-to-real gap 被完全解決。
    5. 如果教授想問更直接的 hardware model comparison，可以補充 paper 其實還有 Figure 7，用同一個 rigid obstacle task 比 ConvNet 和 ViT+LSTM；但這裡先放 Fig. 1，是因為它更完整展示了 high-speed、多障礙、以及 onboard depth-to-command 這三件事。
    6. 預備問題：如果教授問「這能不能算 real-world evaluation」，回答是可以，但要加限定詞：這是 motion-capture indoor arena 下的 representative real trials，不是戶外長距離自主導航。
    7. 預備問題：如果教授問「為什麼這頁沒有數值表格」，回答是因為 Fig. 1 在 paper 本來就是 representative example；真正的 quantitative 重心仍然在前面的 simulation plots 與 ablation table。
  ]
]

#rvl-slide(title: [Conclusion])[
  #grid(
    rows: (0.3fr, 0.7fr),
    gutter: 0.18in,
    block[
      #stat-card([Answer to the central question], [
        #set text(size: 15pt)
        For this task, combining scene-wide spatial context with temporal state produced the most reliable controller, especially at high speed and under environment shift.
      ])
    ],
    block[
      #grid(
        columns: (1fr, 1fr, 1fr),
        gutter: 0.16in,
        stat-card([Empirical takeaway], [
          #set text(size: 13.5pt)
          ViT+LSTM is the only model that consistently surpasses the expert beyond *5 m/s* and clearly leads other students beyond *6 m/s*.
        ]),
        stat-card([Why this matters], [
          #set text(size: 13.5pt)
          The paper isolates *spatial context* and *temporal state* under one imitation-learning protocol.
        ]),
        stat-card([Scope and limitation], [
          #set text(size: 13.5pt)
          Evidence includes zero-shot hardware transfer, but only in a controlled motion-capture arena.
        ]),
      )
    ],
  )

  #speaker-note[
    1. 最後一頁直接回答一開始的 central question。這篇 paper 給出的答案是：在這個高速 depth-based quadrotor avoidance 任務裡，把較大範圍的空間脈絡和 temporal state 放在同一個 end-to-end controller 裡，確實比 purely local spatial encoding 的設計更可靠。
    2. empirical takeaway 可以用來幫觀眾記住最關鍵的兩個數字：超過 5 m/s 之後，它是唯一能穩定超過 expert 的模型；超過 6 m/s 之後，它才開始明顯拉開其他學生模型。
    3. 第二格要回到這篇 paper 真正的學術價值：作者把 spatial context 和 temporal state 這兩個設計軸，在同一個 imitation-learning protocol 裡拆開比較，所以後面的結果才有解釋力。
    4. 最後一格一定要自己先講 limitation，避免被教授接管節奏。這篇工作雖然做了 zero-shot hardware transfer，但場景仍然是 motion-capture indoor arena；因此它支持的是 controlled real-world deployment，而不是 fully open-world autonomous navigation。
    5. 預備問題：如果教授問「那和 traditional modular methods 相比呢」，回答可以直接接回 Figure 6：這篇 paper 不只比較了 neural backbones，也比較了 modular baselines；結論是 modular 方法在固定設計速度附近可以工作，但一旦 desired speed 改變，scalability 會明顯變差，而 ViT+LSTM 在 changing-speed setting 下維持了更好的 collision-performance tradeoff。
    6. 預備問題：如果教授問「所以這篇 paper 的最終貢獻是方法、實驗，還是應用」，回答是三者都有，但最核心的是受控制的 empirical study：它用同一個 task setting 讓我們比較清楚地看到 global visual encoding 與 temporal state 在高速避障裡的作用。
  ]
]

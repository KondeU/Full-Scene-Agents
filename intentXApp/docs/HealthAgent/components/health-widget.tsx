"use client"

import { Line, LineChart, ResponsiveContainer, YAxis } from "recharts"

const weightData = [
  { d: "一", v: 62.5 },
  { d: "二", v: 62.3 },
  { d: "三", v: 62.6 },
  { d: "四", v: 62.1 },
  { d: "五", v: 61.8 },
  { d: "六", v: 61.9 },
  { d: "日", v: 61.5 },
]

const bpData = [
  { d: "一", v: 118 },
  { d: "二", v: 122 },
  { d: "三", v: 120 },
  { d: "四", v: 125 },
  { d: "五", v: 119 },
  { d: "六", v: 121 },
  { d: "日", v: 117 },
]

export default function HealthWidget() {
  return (
    <div className="flex items-center justify-center min-h-screen bg-widget-page-bg">
      {/* Widget 外壳：白色容器 */}
      <div
        className="relative flex flex-row"
        style={{
          width: 360,
          height: 168,
          borderRadius: 24,
          background: "linear-gradient(180deg, #ffffff 0%, #f5fafd 100%)",
          boxShadow: "0 10px 30px 0 rgba(120,170,210,0.22), 0 2px 6px 0 rgba(0,0,0,0.04)",
          padding: 12,
          gap: 12,
        }}
      >
        {/* 左侧：笔记本卡片 */}
        <div className="relative" style={{ width: 132, flexShrink: 0 }}>
          {/* 卡片主体 */}
          <div
            className="relative flex flex-col items-center justify-center w-full h-full overflow-hidden"
            style={{
              borderRadius: 18,
              background: "linear-gradient(160deg, #d6f0f5 0%, #cfeaf6 45%, #c4e4f7 100%)",
              boxShadow: "0 4px 14px 0 rgba(120,180,220,0.18)",
            }}
          >
            {/* 顶部书签标签 */}
            <div
              aria-hidden="true"
              style={{
                position: "absolute",
                top: -2,
                right: 22,
                width: 26,
                height: 30,
                background: "linear-gradient(180deg, #8fd9d6 0%, #b8e8e4 100%)",
                borderRadius: "0 0 8px 8px",
              }}
            />

            {/* 卡通相机拍照按钮 */}
            <button
              aria-label="拍照录入健康数据"
              className="flex items-center justify-center rounded-full transition-transform active:scale-90 hover:scale-105"
              style={{
                width: 64,
                height: 64,
                marginTop: 6,
                marginBottom: 12,
                background: "radial-gradient(circle at 50% 36%, #ffffff 0%, #ffffff 52%, #eaf5fa 100%)",
                boxShadow:
                  "0 12px 22px 0 rgba(95,150,200,0.38), 0 4px 8px 0 rgba(95,150,200,0.22), inset 0 -3px 6px rgba(150,190,225,0.25), inset 0 2px 3px rgba(255,255,255,0.95)",
                border: "none",
                cursor: "pointer",
                padding: 0,
              }}
            >
              <img
                src="/cartoon-camera.png"
                alt="卡通相机"
                width={44}
                height={44}
                style={{ objectFit: "contain", pointerEvents: "none" }}
              />
            </button>

            {/* 文字 */}
            <p
              className="text-center font-semibold"
              style={{
                fontSize: 17,
                color: "#1a1a1a",
                lineHeight: 1.3,
                letterSpacing: 0.3,
              }}
            >
              录入健康数据
            </p>

            {/* 翻页效果：折角投在卡片上的阴影 */}
            <div
              aria-hidden="true"
              style={{
                position: "absolute",
                bottom: 0,
                right: 0,
                width: 40,
                height: 40,
                background: "radial-gradient(circle at 100% 100%, rgba(90,140,180,0.35) 0%, rgba(90,140,180,0.18) 40%, rgba(90,140,180,0) 70%)",
                borderBottomRightRadius: 18,
              }}
            />

            {/* 翻页效果：右下角卷起的纸角 */}
            <div
              aria-hidden="true"
              style={{
                position: "absolute",
                bottom: 0,
                right: 0,
                width: 30,
                height: 30,
                background: "linear-gradient(135deg, rgba(255,255,255,0) 50%, #f3fafc 52%, #dcecf6 100%)",
                borderBottomRightRadius: 18,
                boxShadow: "-3px -3px 6px rgba(110,160,200,0.22), inset -1px -1px 2px rgba(255,255,255,0.6)",
              }}
            />
          </div>
        </div>

        {/* 右侧：本周健康周报 */}
        <div className="flex flex-1 flex-col" style={{ gap: 6, minWidth: 0 }}>
          {/* 标题行 */}
          <div className="flex items-center justify-between">
            <span style={{ fontSize: 14, fontWeight: 600, color: "#1a1a1a" }}>本周健康周报</span>
            <span style={{ fontSize: 11, color: "#8aa6bd" }}>查看全部 ›</span>
          </div>

          {/* 体重曲线 */}
          <div
            className="flex flex-1 flex-col"
            style={{
              borderRadius: 12,
              background: "linear-gradient(150deg, #e9f6ff 0%, #dcefff 100%)",
              padding: "6px 10px",
              minHeight: 0,
            }}
          >
            <div className="flex items-baseline justify-between">
              <span style={{ fontSize: 10, color: "#6b8fab" }}>体重</span>
              <div className="flex items-baseline" style={{ gap: 2 }}>
                <span style={{ fontSize: 13, fontWeight: 700, color: "#2b6cb0" }}>61.5</span>
                <span style={{ fontSize: 9, color: "#9bb3c7" }}>kg</span>
              </div>
            </div>
            <div className="flex-1" style={{ minHeight: 0 }}>
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={weightData} margin={{ top: 4, right: 2, bottom: 0, left: 2 }}>
                  <YAxis domain={["dataMin - 0.3", "dataMax + 0.3"]} hide />
                  <Line type="monotone" dataKey="v" stroke="#2b6cb0" strokeWidth={2} dot={false} />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </div>

          {/* 血压曲线 */}
          <div
            className="flex flex-1 flex-col"
            style={{
              borderRadius: 12,
              background: "linear-gradient(150deg, #ffeef0 0%, #ffe2e6 100%)",
              padding: "6px 10px",
              minHeight: 0,
            }}
          >
            <div className="flex items-baseline justify-between">
              <span style={{ fontSize: 10, color: "#b08a90" }}>血压</span>
              <div className="flex items-baseline" style={{ gap: 2 }}>
                <span style={{ fontSize: 13, fontWeight: 700, color: "#d6536d" }}>117</span>
                <span style={{ fontSize: 9, color: "#c79bab" }}>mmHg</span>
              </div>
            </div>
            <div className="flex-1" style={{ minHeight: 0 }}>
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={bpData} margin={{ top: 4, right: 2, bottom: 0, left: 2 }}>
                  <YAxis domain={["dataMin - 3", "dataMax + 3"]} hide />
                  <Line type="monotone" dataKey="v" stroke="#d6536d" strokeWidth={2} dot={false} />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

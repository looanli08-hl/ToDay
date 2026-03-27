if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Index_Params {
    moodLabel?: string;
    statusLabel?: string;
    syncLabel?: string;
    cards?: Array<WatchSummaryCard>;
    events?: Array<WatchEventItem>;
}
class WatchSummaryCard {
    readonly id: string;
    readonly label: string;
    readonly value: string;
    readonly detail: string;
    readonly tone: string;
    constructor(id: string, label: string, value: string, detail: string, tone: string) {
        this.id = id;
        this.label = label;
        this.value = value;
        this.detail = detail;
        this.tone = tone;
    }
}
class WatchEventItem {
    readonly id: string;
    readonly timeLabel: string;
    readonly title: string;
    readonly detail: string;
    readonly tone: string;
    constructor(id: string, timeLabel: string, title: string, detail: string, tone: string) {
        this.id = id;
        this.timeLabel = timeLabel;
        this.title = title;
        this.detail = detail;
        this.tone = tone;
    }
}
class Index extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__moodLabel = new ObservedPropertySimplePU('🌿 平静', this, "moodLabel");
        this.__statusLabel = new ObservedPropertySimplePU('今天以户外跑步为主，手表端保留最常看的高频信息。', this, "statusLabel");
        this.__syncLabel = new ObservedPropertySimplePU('已切换到手表快速视图', this, "syncLabel");
        this.cards = [
            new WatchSummaryCard('sleep', '睡眠', '7h 55m', '恢复窗口', '#A7B8FF'),
            new WatchSummaryCard('move', '移动', '2h 24m', '步行 + 跑步', '#82D3BE'),
            new WatchSummaryCard('note', '记录', '2 条', '含 1 条备注', '#E3B17B')
        ];
        this.events = [
            new WatchEventItem('w1', '06:40', '结束睡眠', '起床后节律平稳，恢复情况不错。', '#A7B8FF'),
            new WatchEventItem('w2', '11:20', '午间快走', '12 分钟快走，延续日间活动感。', '#82D3BE'),
            new WatchEventItem('w3', '18:10', '户外跑步', '今天最明显的推进片段，强度适中。', '#E8905B')
        ];
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Index_Params) {
        if (params.moodLabel !== undefined) {
            this.moodLabel = params.moodLabel;
        }
        if (params.statusLabel !== undefined) {
            this.statusLabel = params.statusLabel;
        }
        if (params.syncLabel !== undefined) {
            this.syncLabel = params.syncLabel;
        }
        if (params.cards !== undefined) {
            this.cards = params.cards;
        }
        if (params.events !== undefined) {
            this.events = params.events;
        }
    }
    updateStateVars(params: Index_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__moodLabel.purgeDependencyOnElmtId(rmElmtId);
        this.__statusLabel.purgeDependencyOnElmtId(rmElmtId);
        this.__syncLabel.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__moodLabel.aboutToBeDeleted();
        this.__statusLabel.aboutToBeDeleted();
        this.__syncLabel.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __moodLabel: ObservedPropertySimplePU<string>;
    get moodLabel() {
        return this.__moodLabel.get();
    }
    set moodLabel(newValue: string) {
        this.__moodLabel.set(newValue);
    }
    private __statusLabel: ObservedPropertySimplePU<string>;
    get statusLabel() {
        return this.__statusLabel.get();
    }
    set statusLabel(newValue: string) {
        this.__statusLabel.set(newValue);
    }
    private __syncLabel: ObservedPropertySimplePU<string>;
    get syncLabel() {
        return this.__syncLabel.get();
    }
    set syncLabel(newValue: string) {
        this.__syncLabel.set(newValue);
    }
    private readonly cards: Array<WatchSummaryCard>;
    private readonly events: Array<WatchEventItem>;
    private buildHero(parent = null): void {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 10 });
            Column.debugLine("wear/src/main/ets/pages/Index.ets(54:5)", "wear");
            Column.alignItems(HorizontalAlign.Center);
            Column.width('100%');
            Column.padding(18);
            Column.backgroundColor('#202522');
            Column.borderRadius(32);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('ToDay');
            Text.debugLine("wear/src/main/ets/pages/Index.ets(55:7)", "wear");
            Text.fontSize(24);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor('#F8F4EC');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('Watch GT 5 快速视图');
            Text.debugLine("wear/src/main/ets/pages/Index.ets(60:7)", "wear");
            Text.fontSize(12);
            Text.fontColor('#B8B2A9');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.debugLine("wear/src/main/ets/pages/Index.ets(64:7)", "wear");
            Stack.width('100%');
            Stack.height(208);
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 8 });
            Column.debugLine("wear/src/main/ets/pages/Index.ets(65:9)", "wear");
            Column.justifyContent(FlexAlign.Center);
            Column.width(176);
            Column.height(176);
            Column.borderRadius(999);
            Column.backgroundColor('#171A18');
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('今日节律');
            Text.debugLine("wear/src/main/ets/pages/Index.ets(66:11)", "wear");
            Text.fontSize(12);
            Text.fontColor('#B8B2A9');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('稳定推进');
            Text.debugLine("wear/src/main/ets/pages/Index.ets(70:11)", "wear");
            Text.fontSize(28);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor('#F8F4EC');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.moodLabel);
            Text.debugLine("wear/src/main/ets/pages/Index.ets(75:11)", "wear");
            Text.fontSize(13);
            Text.fontColor('#1A1A1A');
            Text.padding({ left: 12, right: 12, top: 6, bottom: 6 });
            Text.backgroundColor('#E9D5B7');
            Text.borderRadius(999);
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("wear/src/main/ets/pages/Index.ets(88:9)", "wear");
            Column.width(208);
            Column.height(208);
            Column.borderRadius(999);
            Column.border({
                width: 10,
                color: '#2A2F2B'
            });
        }, Column);
        Column.pop();
        Stack.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.statusLabel);
            Text.debugLine("wear/src/main/ets/pages/Index.ets(100:7)", "wear");
            Text.fontSize(13);
            Text.lineHeight(20);
            Text.fontColor('#D6D0C8');
        }, Text);
        Text.pop();
        Column.pop();
    }
    private buildSummaryCard(item: WatchSummaryCard, parent = null): void {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 6 });
            Column.debugLine("wear/src/main/ets/pages/Index.ets(114:5)", "wear");
            Column.alignItems(HorizontalAlign.Start);
            Column.layoutWeight(1);
            Column.padding(14);
            Column.backgroundColor('#202522');
            Column.borderRadius(24);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(item.label);
            Text.debugLine("wear/src/main/ets/pages/Index.ets(115:7)", "wear");
            Text.fontSize(12);
            Text.fontColor('#A9A39A');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(item.value);
            Text.debugLine("wear/src/main/ets/pages/Index.ets(119:7)", "wear");
            Text.fontSize(22);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor('#F8F4EC');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(item.detail);
            Text.debugLine("wear/src/main/ets/pages/Index.ets(124:7)", "wear");
            Text.fontSize(11);
            Text.fontColor(item.tone);
        }, Text);
        Text.pop();
        Column.pop();
    }
    private buildEventCard(item: WatchEventItem, parent = null): void {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 10 });
            Row.debugLine("wear/src/main/ets/pages/Index.ets(137:5)", "wear");
            Row.width('100%');
            Row.padding(14);
            Row.backgroundColor('#202522');
            Row.borderRadius(24);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("wear/src/main/ets/pages/Index.ets(138:7)", "wear");
            Column.width(10);
            Column.height(10);
            Column.borderRadius(999);
            Column.backgroundColor(item.tone);
            Column.margin({ top: 6 });
        }, Column);
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 4 });
            Column.debugLine("wear/src/main/ets/pages/Index.ets(145:7)", "wear");
            Column.alignItems(HorizontalAlign.Start);
            Column.layoutWeight(1);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("wear/src/main/ets/pages/Index.ets(146:9)", "wear");
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(item.title);
            Text.debugLine("wear/src/main/ets/pages/Index.ets(147:11)", "wear");
            Text.fontSize(15);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor('#F8F4EC');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
            Blank.debugLine("wear/src/main/ets/pages/Index.ets(152:11)", "wear");
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(item.timeLabel);
            Text.debugLine("wear/src/main/ets/pages/Index.ets(154:11)", "wear");
            Text.fontSize(11);
            Text.fontColor('#B8B2A9');
        }, Text);
        Text.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(item.detail);
            Text.debugLine("wear/src/main/ets/pages/Index.ets(160:9)", "wear");
            Text.fontSize(12);
            Text.lineHeight(18);
            Text.fontColor('#D6D0C8');
        }, Text);
        Text.pop();
        Column.pop();
        Row.pop();
    }
    private buildActionRow(parent = null): void {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 10 });
            Row.debugLine("wear/src/main/ets/pages/Index.ets(176:5)", "wear");
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('记心情');
            Button.debugLine("wear/src/main/ets/pages/Index.ets(177:7)", "wear");
            Button.layoutWeight(1);
            Button.fontSize(13);
            Button.fontColor('#10110F');
            Button.backgroundColor('#D9B27E');
            Button.borderRadius(999);
            Button.onClick(() => {
                this.moodLabel = '✨ 满足';
                this.syncLabel = '已在手表端记录一条情绪';
            });
        }, Button);
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('同步手机');
            Button.debugLine("wear/src/main/ets/pages/Index.ets(188:7)", "wear");
            Button.layoutWeight(1);
            Button.fontSize(13);
            Button.fontColor('#F8F4EC');
            Button.backgroundColor('#2C332E');
            Button.borderRadius(999);
            Button.onClick(() => {
                this.syncLabel = '已准备和手机端时间轴对齐';
            });
        }, Button);
        Button.pop();
        Row.pop();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Scroll.create();
            Scroll.debugLine("wear/src/main/ets/pages/Index.ets(202:5)", "wear");
            Scroll.scrollBar(BarState.Off);
            Scroll.width('100%');
            Scroll.height('100%');
            Scroll.backgroundColor('#111412');
        }, Scroll);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 12 });
            Column.debugLine("wear/src/main/ets/pages/Index.ets(203:7)", "wear");
            Column.padding({ left: 16, right: 16, top: 18, bottom: 28 });
            Column.width('100%');
        }, Column);
        this.buildHero.bind(this)();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 10 });
            Row.debugLine("wear/src/main/ets/pages/Index.ets(206:9)", "wear");
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = _item => {
                const item = _item;
                this.buildSummaryCard.bind(this)(item);
            };
            this.forEachUpdateFunction(elmtId, this.cards, forEachItemGenFunction, (item: WatchSummaryCard): string => item.id, false, false);
        }, ForEach);
        ForEach.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('关键片段');
            Text.debugLine("wear/src/main/ets/pages/Index.ets(213:9)", "wear");
            Text.width('100%');
            Text.fontSize(16);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor('#F8F4EC');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = _item => {
                const item = _item;
                this.buildEventCard.bind(this)(item);
            };
            this.forEachUpdateFunction(elmtId, this.events, forEachItemGenFunction, (item: WatchEventItem): string => item.id, false, false);
        }, ForEach);
        ForEach.pop();
        this.buildActionRow.bind(this)();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.syncLabel);
            Text.debugLine("wear/src/main/ets/pages/Index.ets(225:9)", "wear");
            Text.width('100%');
            Text.fontSize(12);
            Text.lineHeight(18);
            Text.fontColor('#A9A39A');
            Text.textAlign(TextAlign.Center);
        }, Text);
        Text.pop();
        Column.pop();
        Scroll.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    static getEntryName(): string {
        return "Index";
    }
}
registerNamedRoute(() => new Index(undefined, {}), "", { bundleName: "com.looanli.today", moduleName: "wear", pagePath: "pages/Index", pageFullPath: "wear/src/main/ets/pages/Index", integratedHsp: "false", moduleType: "followWithHap" });

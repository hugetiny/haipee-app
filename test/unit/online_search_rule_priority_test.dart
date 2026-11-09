import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/bilibili/bilibili_models.dart';
import 'package:haipee/pages/online/online_video_search_provider.dart';

void main() {
  group('OnlineVideoSearch Rule Priority Tests', () {
    test('ruleTypePriority assigns correct order to rule types', () {
      const haipeeItem = BiliVideoItem(
        bvid: 'web_haipee_1',
        title: 'Haipee 视频',
        author: 'haipee_src',
        pic: '',
        ruleType: 'haipee',
      );
      const kazumiItem = BiliVideoItem(
        bvid: 'web_kazumi_1',
        title: 'Kazumi 番剧',
        author: 'kazumi_src',
        pic: '',
        ruleType: 'kazumi',
      );
      const maccmsItem = BiliVideoItem(
        bvid: 'web_maccms_1',
        title: 'MacCMS 采集',
        author: 'maccms_src',
        pic: '',
        ruleType: 'maccms',
      );
      const tvboxItem = BiliVideoItem(
        bvid: 'web_tvbox_1',
        title: 'TVBox 量子点播',
        author: 'tvbox_src',
        pic: '',
        ruleType: 'tvbox',
      );
      const pipedItem = BiliVideoItem(
        bvid: 'web_piped_1',
        title: 'Piped 视频',
        author: 'piped_src',
        pic: '',
        ruleType: 'piped',
      );
      const iptvItem = BiliVideoItem(
        bvid: 'web_iptv_1',
        title: 'IPTV 直播',
        author: 'iptv_src',
        pic: '',
        ruleType: 'iptv',
      );

      expect(OnlineVideoSearchState.ruleTypePriority(haipeeItem), 0);
      expect(OnlineVideoSearchState.ruleTypePriority(kazumiItem), 0);
      expect(OnlineVideoSearchState.ruleTypePriority(maccmsItem), 1);
      expect(OnlineVideoSearchState.ruleTypePriority(tvboxItem), 2);
      expect(OnlineVideoSearchState.ruleTypePriority(pipedItem), 3);
      expect(OnlineVideoSearchState.ruleTypePriority(iptvItem), 4);
    });

    test('sortResultsByRulePriority places Haipee rules at top even when TVBox is added first', () {
      const tvboxItem = BiliVideoItem(
        bvid: 'web_tvbox_1',
        title: 'TVBox 量子点播',
        author: 'tvbox_src',
        pic: '',
        ruleType: 'tvbox',
      );
      const maccmsItem = BiliVideoItem(
        bvid: 'web_maccms_1',
        title: 'MacCMS 采集',
        author: 'maccms_src',
        pic: '',
        ruleType: 'maccms',
      );
      const haipeeItem = BiliVideoItem(
        bvid: 'web_haipee_1',
        title: 'Haipee 原生规则',
        author: 'haipee_src',
        pic: '',
        ruleType: 'haipee',
      );

      // Even if TVBox was discovered first, sorted order must be Haipee -> MacCMS -> TVBox
      final unordered = <BiliVideoItem>[tvboxItem, maccmsItem, haipeeItem];
      final sorted = OnlineVideoSearchState.sortResultsByRulePriority(unordered);

      expect(sorted[0].ruleType, 'haipee');
      expect(sorted[0].title, 'Haipee 原生规则');
      expect(sorted[1].ruleType, 'maccms');
      expect(sorted[1].title, 'MacCMS 采集');
      expect(sorted[2].ruleType, 'tvbox');
      expect(sorted[2].title, 'TVBox 量子点播');
    });

    test('OnlineVideoSearchState currentFilteredResults maintains Haipee at the top', () {
      const tvboxItem = BiliVideoItem(
        bvid: 'web_tvbox_1',
        title: 'TVBox 电影',
        author: 'tvbox_src',
        pic: '',
        ruleType: 'tvbox',
      );
      const haipeeItem = BiliVideoItem(
        bvid: 'web_haipee_1',
        title: 'Haipee 优质动漫',
        author: 'haipee_src',
        pic: '',
        ruleType: 'haipee',
      );

      final state = OnlineVideoSearchState(
        allResults: const [tvboxItem, haipeeItem],
      );

      final filtered = state.currentFilteredResults;
      expect(filtered.length, 2);
      expect(filtered.first.bvid, 'web_haipee_1');
      expect(filtered.last.bvid, 'web_tvbox_1');
    });

    test('Direct match items remain at index 0 ahead of all rules', () {
      const directItem = BiliVideoItem(
        bvid: 'BV1xx411c7mD',
        title: 'B站精选视频直达',
        author: 'UP主',
        pic: '',
        ruleType: 'piped',
      );
      const haipeeItem = BiliVideoItem(
        bvid: 'web_haipee_1',
        title: 'Haipee 规则视频',
        author: 'haipee_src',
        pic: '',
        ruleType: 'haipee',
      );
      const tvboxItem = BiliVideoItem(
        bvid: 'web_tvbox_1',
        title: 'TVBox 视频',
        author: 'tvbox_src',
        pic: '',
        ruleType: 'tvbox',
      );

      final sorted = OnlineVideoSearchState.sortResultsByRulePriority(
        const [tvboxItem, haipeeItem, directItem],
        directMatchBvids: {directItem.bvid},
      );

      expect(sorted[0].bvid, directItem.bvid);
      expect(sorted[1].bvid, haipeeItem.bvid);
      expect(sorted[2].bvid, tvboxItem.bvid);
    });
  });
}

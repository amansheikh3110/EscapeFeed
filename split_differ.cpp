#include <iostream>
#include <vector>
#include <algorithm>

using namespace std;

struct Cand {
    int sz;
    long long vals[3];
};

struct State {
    long long prev_last;
    Cand cand;
};

vector<Cand> get_cands(long long val) {
    vector<Cand> cands;
    cands.push_back({1, {val, 0, 0}});
    if (val >= 2) {
        for (long long first = 1; first <= min(val - 1, 3LL); first++) {
            long long second = val - first;
            if (first != second) {
                cands.push_back({2, {first, second, 0}});
            }
        }
    }
    if (val >= 3) {
        for (long long first = 1; first <= min(val - 2, 3LL); first++) {
            for (long long last = 1; last <= min(val - first - 1, 3LL); last++) {
                long long middle = val - first - last;
                if (middle > 0 && first != middle && middle != last) {
                    cands.push_back({3, {first, middle, last}});
                }
            }
        }
    }
    return cands;
}

void solve() {
    int N;
    if (!(cin >> N)) return;
    vector<long long> A(N);
    for (int i = 0; i < N; i++) {
        cin >> A[i];
    }

    vector<vector<pair<long long, State>>> dp(N);

    for (int i = 0; i < N; i++) {
        long long val = A[i];
        vector<Cand> cands = get_cands(val);
        
        if (i == 0) {
            for (auto const& c : cands) {
                long long last_val = c.vals[c.sz - 1];
                bool found = false;
                for (auto& p : dp[i]) {
                    if (p.first == last_val) { found = true; break; }
                }
                if (!found) {
                    dp[i].push_back({last_val, {-1, c}});
                }
            }
        } else {
            for (auto const& p_prev : dp[i-1]) {
                long long prev_last = p_prev.first;
                for (auto const& c : cands) {
                    if (c.vals[0] == prev_last) continue;
                    long long new_last = c.vals[c.sz - 1];
                    bool found = false;
                    for (auto& p : dp[i]) {
                        if (p.first == new_last) { found = true; break; }
                    }
                    if (!found) {
                        dp[i].push_back({new_last, {prev_last, c}});
                    }
                }
            }
        }
        
        if (dp[i].empty()) {
            cout << -1 << "\n";
            return;
        }
    }

    vector<Cand> ans_cands(N);
    long long curr_last = dp[N-1][0].first;
    
    for (int i = N - 1; i >= 0; i--) {
        State st;
        for (auto const& p : dp[i]) {
            if (p.first == curr_last) {
                st = p.second;
                break;
            }
        }
        ans_cands[i] = st.cand;
        curr_last = st.prev_last;
    }

    vector<long long> final_ans;
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < ans_cands[i].sz; j++) {
            final_ans.push_back(ans_cands[i].vals[j]);
        }
    }

    cout << final_ans.size() << "\n";
    for (int i = 0; i < final_ans.size(); i++) {
        cout << final_ans[i] << (i == final_ans.size() - 1 ? "" : " ");
    }
    cout << "\n";
}

int main() {
    ios_base::sync_with_stdio(false);
    cin.tie(NULL);
    int T;
    if (cin >> T) {
        while (T--) solve();
    }
    return 0;
}

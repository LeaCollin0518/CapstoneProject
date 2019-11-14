import numpy as np

# FIRST SEARCH
# Search Space
space = np.logspace(-2, 1, 4)
vals = np.array(np.meshgrid(space, space)).T.reshape(-1, 2)

# CV Results - mean squared loss
results = [2252.3606, 2337.7651, 2295.913, 2280.6477, 2266.9426,
            2280.5017, 2186.1035, 2318.9883, 2351.9563, 2335.9473,
            2378.7766, 2349.1418, 2353.656, 2265.7617, 2268.165, 2291.7273]

best_idx = np.argmin(results)
best_val = vals[best_idx]
# best_val = array([0.1, 1. ])


# SECOND SEARCH
# Search Space
space1 = np.logspace(-4, 0, 4, base=2)
space2 = np.logspace(-1, 1, 4, base=2)
vals = np.array(np.meshgrid(space1, space2)).T.reshape(-1, 2)

# Results
results_2 = [[8265.859, 1653.1719], [8253.328, 1650.6656],
                [8217.183, 1643.4365], [8142.6304, 1628.5261],
                [8369.404, 1673.8809], [8397.298, 1679.4596],
                [8208.029, 1641.6058], [8425.31, 1685.0619],
                [8366.848, 1673.3695], [8440.584, 1688.1168],
                [8318.226, 1663.6451], [8381.989, 1676.3978],
                [8526.392, 1705.2783], [8552.285, 1710.457],
                [8459.986, 1691.9973], [8352.263, 1670.4525]]
sums = [x[0] for x in results_2]
means = [x[1] for x in results_2]
assert np.argmin(sums) == np.argmin(means)
best_idx = np.argmin(sums)
best_val = vals[best_idx]
# best_val = array([0.0625, 2.    ])

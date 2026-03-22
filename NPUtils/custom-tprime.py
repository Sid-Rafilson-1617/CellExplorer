import numpy as np
from scipy.interpolate import interp1d

def make_timewarp(ref_edges, other_edges):
    """
    Returns a function mapping reference-clock times -> other-clock times
    using piecewise-linear interpolation of matched sync edges.

    This function can be used as tprime to warp times from one clock to another, e.g. to warp ripple times detected on one probe to the timebase of another probe for plotting.

    Parameters
    ----------
    ref_edges : array-like
        Reference clock edge times.
    other_edges : array-like
        Other clock edge times to map to.

    Returns
    -------
    function
        A function that maps reference-clock times to other-clock times.
    """


    ref_edges = np.asarray(ref_edges, dtype=float)
    other_edges = np.asarray(other_edges, dtype=float)

    n = min(len(ref_edges), len(other_edges))
    ref_edges = ref_edges[:n]
    other_edges = other_edges[:n]

    # keep only finite, strictly increasing pairs
    good = np.isfinite(ref_edges) & np.isfinite(other_edges)
    ref_edges = ref_edges[good]
    other_edges = other_edges[good]

    # optional safety against duplicated edges
    keep = np.r_[True, (np.diff(ref_edges) > 0) & (np.diff(other_edges) > 0)]
    ref_edges = ref_edges[keep]
    other_edges = other_edges[keep]

    return interp1d(
        ref_edges,
        other_edges,
        kind="linear",
        bounds_error=False,
        fill_value="extrapolate",
        assume_sorted=True,
    )
import UIKit

/// Vertical layout: AI toolbar (fixed top row) → status → keyplane (fills remainder).
enum KeyboardRootViewLayout {
    struct Constraints {
        var toolbarHeight: NSLayoutConstraint?
        var statusHeight: NSLayoutConstraint?
        var previewHeight: NSLayoutConstraint?
    }

    static func install(
        on parent: UIView,
        surfaceCover: UIView? = nil,
        toolbarRow: UIView,
        statusRow: UIView,
        keyContainer: UIView,
        previewOverlay: UIView,
        toolbarDesignHeight: CGFloat
    ) -> Constraints {
        if let surfaceCover, surfaceCover.superview == nil {
            surfaceCover.translatesAutoresizingMaskIntoConstraints = false
            surfaceCover.isUserInteractionEnabled = false
            parent.addSubview(surfaceCover)
            NSLayoutConstraint.activate([
                surfaceCover.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
                surfaceCover.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
                surfaceCover.topAnchor.constraint(equalTo: parent.topAnchor),
                surfaceCover.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
            ])
        }

        toolbarRow.translatesAutoresizingMaskIntoConstraints = false
        statusRow.translatesAutoresizingMaskIntoConstraints = false
        keyContainer.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(toolbarRow)
        parent.addSubview(statusRow)
        parent.addSubview(keyContainer)

        let toolbarH = toolbarRow.heightAnchor.constraint(equalToConstant: toolbarDesignHeight)
        toolbarH.priority = .required

        let statusH = statusRow.heightAnchor.constraint(equalToConstant: 0)
        statusH.priority = .required

        NSLayoutConstraint.activate([
            toolbarRow.topAnchor.constraint(equalTo: parent.topAnchor),
            toolbarRow.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            toolbarRow.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            toolbarH,

            statusRow.topAnchor.constraint(equalTo: toolbarRow.bottomAnchor),
            statusRow.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            statusRow.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            statusH,

            keyContainer.topAnchor.constraint(equalTo: statusRow.bottomAnchor),
            keyContainer.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            keyContainer.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            keyContainer.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
        ])

        previewOverlay.translatesAutoresizingMaskIntoConstraints = false
        previewOverlay.isUserInteractionEnabled = true
        previewOverlay.layer.cornerRadius = 14
        previewOverlay.clipsToBounds = true
        parent.insertSubview(previewOverlay, aboveSubview: keyContainer)

        let oh = previewOverlay.heightAnchor.constraint(equalToConstant: 0)
        oh.priority = .required
        oh.isActive = true
        NSLayoutConstraint.activate([
            previewOverlay.topAnchor.constraint(equalTo: parent.topAnchor, constant: 4),
            previewOverlay.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: 8),
            previewOverlay.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -8),
            oh,
        ])

        return Constraints(
            toolbarHeight: toolbarH,
            statusHeight: statusH,
            previewHeight: oh
        )
    }
}

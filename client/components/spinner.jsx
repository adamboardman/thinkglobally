import React from 'react';
import './spinner.css';

// Mostly borrowed from https://github.com/jaredpalmer/react-conf-2018/blob/master/full-suspense/src/components/Spinner.js
export function Spinner() {
    const baseSize = 40;
    const pathSize = baseSize / 2;
    const strokeWidth = 4;
    const pathRadius = `${baseSize / 2 - strokeWidth}px`;

    return (
        <div className="SpinnerContainer">
            <svg
                className="Spinner"
                width={baseSize}
                height={baseSize}
                viewBox={`0 0 ${baseSize} ${baseSize}`}
            >
                <circle
                    className="SpinnerPath"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={strokeWidth}
                    strokeLinecap="round"
                    cx={pathSize}
                    cy={pathSize}
                    r={pathRadius}
                />
            </svg>
        </div>
    );
}